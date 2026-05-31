import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/comment_model.dart';
import '../models/post_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class HashtagResult {
  final String tag;
  final int postCount;

  const HashtagResult({
    required this.tag,
    required this.postCount,
  });

  factory HashtagResult.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HashtagResult(
      tag: data['tag']?.toString() ?? doc.id,
      postCount: data['postCount'] is int ? data['postCount'] as int : 0,
    );
  }
}

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<String> uploadPost({
    required List<File> mediaFiles,
    required String mediaType,
    required String description,
    required String userId,
    required String username,
    required String userPhotoUrl,
    List<Map<String, dynamic>> taggedUsers = const [],
    void Function(double progress)? onProgress,
  }) async {
    try {
      final postId = _uuid.v4();
      var mediaUrls = <String>[];

      if (mediaType == 'video') {
        final url = await StorageService.uploadVideo(
          mediaFiles.first,
          onProgress: onProgress,
        );
        if (url == null) return 'Lỗi upload video';
        mediaUrls = [url];
      } else {
        mediaUrls = await StorageService.uploadMultipleImages(
          mediaFiles,
          onProgress: onProgress,
        );
        if (mediaUrls.isEmpty) return 'Lỗi upload ảnh';
      }

      final post = PostModel(
        postId: postId,
        ownerId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        mediaUrls: mediaUrls,
        mediaType: mediaType,
        description: description,
        likes: {},
        timestamp: Timestamp.now(),
        taggedUsers: taggedUsers,
      );

      final hashtags = _extractHashtags(description);
      await _db.collection('posts').doc(postId).set({
        ...post.toMap(),
        'hashtags': hashtags,
        'searchKeywords': _buildSearchKeywords(
          description: description,
          username: username,
        ),
      });
      await _syncHashtagCounts(oldTags: const [], newTags: hashtags);

      await _notifyTaggedUsers(
        taggedUsers: taggedUsers,
        fromUserId: userId,
        fromUsername: username,
        fromUserPhotoUrl: userPhotoUrl,
        type: 'tag_post',
        postId: postId,
        mediaUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<PostModel>> getAllPosts() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromDoc).toList());
  }

  Future<List<PostModel>> getRecentPosts({int limit = 100}) async {
    final snap = await _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map(PostModel.fromDoc).toList();
  }

  Future<List<PostModel>> searchPosts(String query, {int limit = 100}) async {
    final normalizedQuery = _normalizeForSearch(query.trim());
    if (normalizedQuery.isEmpty) return [];

    final cleanQuery = normalizedQuery.startsWith('#')
        ? normalizedQuery.substring(1)
        : normalizedQuery;

    if (cleanQuery.isEmpty) return [];

    try {
      QuerySnapshot<Map<String, dynamic>> snap;

      if (normalizedQuery.startsWith('#')) {
        snap = await _db
            .collection('posts')
            .where('hashtags', arrayContains: cleanQuery)
            .limit(limit)
            .get();
      } else {
        final tokens = _buildQueryTokens(cleanQuery).take(10).toList();
        if (tokens.isEmpty) return [];

        snap = await _db
            .collection('posts')
            .where('searchKeywords', arrayContainsAny: tokens)
            .limit(limit)
            .get();
      }

      final posts = snap.docs.map(PostModel.fromDoc).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (posts.isNotEmpty) return posts;
    } catch (_) {
      // Fall back to local filtering for older Firestore indexes/rules.
    }

    return _fallbackSearchPosts(cleanQuery, limit: limit);
  }

  Future<List<PostModel>> getPostsByHashtag(
    String tag, {
    int limit = 100,
  }) async {
    final normalizedTag = _normalizeForSearch(tag).replaceFirst('#', '');
    if (normalizedTag.isEmpty) return [];

    try {
      final snap = await _db
          .collection('posts')
          .where('hashtags', arrayContains: normalizedTag)
          .limit(limit)
          .get();

      final posts = snap.docs.map(PostModel.fromDoc).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (posts.isNotEmpty) return posts;
    } catch (_) {
      // Fall back to recent-post filtering for older data/indexes.
    }

    final posts = await getRecentPosts(limit: limit);
    return posts.where((post) {
      return _extractHashtags(post.description).contains(normalizedTag);
    }).toList();
  }

  Future<List<HashtagResult>> searchHashtags(
    String query, {
    int limit = 100,
  }) async {
    final normalizedQuery =
        _normalizeForSearch(query.trim()).replaceFirst('#', '');
    if (normalizedQuery.isEmpty) return [];

    try {
      final snap = await _db
          .collection('hashtags')
          .orderBy('tag')
          .startAt([normalizedQuery])
          .endAt(['$normalizedQuery\uf8ff'])
          .limit(20)
          .get();

      final results = snap.docs
          .map(HashtagResult.fromDoc)
          .where((item) => item.postCount > 0)
          .toList()
        ..sort((a, b) => b.postCount.compareTo(a.postCount));

      if (results.isNotEmpty) return results;
    } catch (_) {
      // Fall back to recent-post aggregation for data that is not indexed yet.
    }

    return _fallbackSearchHashtags(normalizedQuery, limit: limit);
  }

  Future<List<HashtagResult>> getTrendingHashtags({int limit = 100}) async {
    try {
      final snap = await _db
          .collection('hashtags')
          .where('postCount', isGreaterThan: 0)
          .orderBy('postCount', descending: true)
          .limit(10)
          .get();

      final results = snap.docs.map(HashtagResult.fromDoc).toList();
      if (results.isNotEmpty) return results;
    } catch (_) {
      // Fall back to recent-post aggregation for data that is not indexed yet.
    }

    return _fallbackTrendingHashtags(limit: limit);
  }

  Future<int> rebuildRecentSearchIndex({int limit = 500}) async {
    final postsSnap = await _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    final allTags = <String, int>{};
    var batch = _db.batch();
    var pendingWrites = 0;

    for (final doc in postsSnap.docs) {
      final post = PostModel.fromDoc(doc);
      final hashtags = _extractHashtags(post.description);

      for (final tag in hashtags) {
        allTags[tag] = (allTags[tag] ?? 0) + 1;
      }

      batch.update(doc.reference, {
        'hashtags': hashtags,
        'searchKeywords': _buildSearchKeywords(
          description: post.description,
          username: post.username,
        ),
      });
      pendingWrites++;

      if (pendingWrites >= 400) {
        await batch.commit();
        batch = _db.batch();
        pendingWrites = 0;
      }
    }

    for (final entry in allTags.entries) {
      batch.set(
        _db.collection('hashtags').doc(entry.key),
        {
          'tag': entry.key,
          'postCount': entry.value,
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
      pendingWrites++;

      if (pendingWrites >= 400) {
        await batch.commit();
        batch = _db.batch();
        pendingWrites = 0;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }

    return postsSnap.docs.length;
  }

  Stream<List<PostModel>> getFeedPosts(List followingAndMe, int limit) {
    if (followingAndMe.isEmpty) {
      return Stream.value([]);
    }

    final ownerIds = followingAndMe.map((id) => id.toString()).toSet().toList();
    final streams = <Stream<List<PostModel>>>[];

    for (var i = 0; i < ownerIds.length; i += 10) {
      final chunk = ownerIds.skip(i).take(10).toList();

      streams.add(
        _db
            .collection('posts')
            .where('ownerId', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => snap.docs.map(PostModel.fromDoc).toList()),
      );
    }

    if (streams.length == 1) {
      return streams.first.map((posts) => _sortAndLimit(posts, limit));
    }

    return _combinePostStreams(streams, limit);
  }

  Stream<List<PostModel>> getUserPosts(String userId) {
    return _db
        .collection('posts')
        .where('ownerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromDoc).toList());
  }

  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();

      if (!doc.exists) {
        return null;
      }

      return PostModel.fromDoc(doc);
    } catch (e) {
      return null;
    }
  }

  Future<String> updatePost({
    required String postId,
    required String currentUserId,
    required String description,
    required List<Map<String, dynamic>> taggedUsers,
    required String fromUsername,
    required String fromUserPhotoUrl,
  }) async {
    try {
      final postRef = _db.collection('posts').doc(postId);
      final postSnap = await postRef.get();

      if (!postSnap.exists) {
        return 'Bài viết không còn tồn tại';
      }

      final post = PostModel.fromDoc(postSnap);
      if (post.ownerId != currentUserId) {
        return 'Bạn không có quyền sửa bài viết này';
      }

      final oldHashtags = _extractHashtags(post.description);
      final newHashtags = _extractHashtags(description);

      await postRef.update({
        'description': description,
        'taggedUsers': taggedUsers,
        'hashtags': newHashtags,
        'searchKeywords': _buildSearchKeywords(
          description: description,
          username: post.username,
        ),
        'updatedAt': Timestamp.now(),
      });
      await _syncHashtagCounts(oldTags: oldHashtags, newTags: newHashtags);

      final oldTaggedIds = post.taggedUsers
          .map((user) => user['uid']?.toString() ?? '')
          .where((uid) => uid.isNotEmpty)
          .toSet();

      final newlyTaggedUsers = taggedUsers.where((user) {
        final uid = user['uid']?.toString() ?? '';
        return uid.isNotEmpty && !oldTaggedIds.contains(uid);
      }).toList();

      await _notifyTaggedUsers(
        taggedUsers: newlyTaggedUsers,
        fromUserId: currentUserId,
        fromUsername: fromUsername,
        fromUserPhotoUrl: fromUserPhotoUrl,
        type: 'tag_post',
        postId: postId,
        mediaUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<PostModel>> getSavedPosts(List savedIds) async {
    if (savedIds.isEmpty) return [];

    final posts = <PostModel>[];

    for (var i = 0; i < savedIds.length; i += 10) {
      final chunk = savedIds.skip(i).take(10).toList();

      final snap =
          await _db.collection('posts').where('postId', whereIn: chunk).get();

      posts.addAll(snap.docs.map(PostModel.fromDoc));
    }

    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return posts;
  }

  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final ref = _db.collection('posts').doc(postId);

    if (isLiked) {
      await ref.update({'likes.$userId': FieldValue.delete()});
    } else {
      await ref.update({'likes.$userId': true});

      final postSnap = await ref.get();

      if (postSnap.exists) {
        final post = PostModel.fromDoc(postSnap);
        final userSnap = await _db.collection('users').doc(userId).get();

        if (userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>;

          NotificationService().sendNotification(
            toUserId: post.ownerId,
            fromUserId: userId,
            fromUsername: userData['username'] ?? '',
            fromUserPhotoUrl: userData['photoUrl'] ?? '',
            type: 'like',
            postId: postId,
            postMediaUrl:
                post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
          );
        }
      }
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String username,
    required String userPhotoUrl,
    required String text,
  }) async {
    final commentId = _uuid.v4();

    final comment = CommentModel(
      commentId: commentId,
      postId: postId,
      userId: userId,
      username: username,
      userPhotoUrl: userPhotoUrl,
      text: text,
      timestamp: Timestamp.now(),
    );

    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .set(comment.toMap());

    final postSnap = await _db.collection('posts').doc(postId).get();

    if (postSnap.exists) {
      final post = PostModel.fromDoc(postSnap);

      NotificationService().sendNotification(
        toUserId: post.ownerId,
        fromUserId: userId,
        fromUsername: username,
        fromUserPhotoUrl: userPhotoUrl,
        type: 'comment',
        postId: postId,
        commentId: commentId,
        postMediaUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
        commentText: text,
      );
    }
  }

  Stream<List<CommentModel>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  Future<void> deletePost(String postId) async {
    final postRef = _db.collection('posts').doc(postId);
    final postSnap = await postRef.get();

    if (!postSnap.exists) return;

    final post = PostModel.fromDoc(postSnap);
    final oldHashtags = _extractHashtags(post.description);

    await _deletePostComments(postRef);
    await postRef.delete();
    await _syncHashtagCounts(oldTags: oldHashtags, newTags: const []);

    try {
      await _deletePostNotifications(postId);
    } catch (_) {
      // Notification cleanup can fail if collection-group rules/indexes are
      // not deployed yet. The post itself is already removed at this point.
    }
  }

  List<PostModel> _sortAndLimit(List<PostModel> posts, int limit) {
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (posts.length <= limit) {
      return posts;
    }

    return posts.take(limit).toList();
  }

  Stream<List<PostModel>> _combinePostStreams(
    List<Stream<List<PostModel>>> streams,
    int limit,
  ) {
    late StreamController<List<PostModel>> controller;
    final latestPosts = List<List<PostModel>?>.filled(streams.length, null);
    final subscriptions = <StreamSubscription<List<PostModel>>>[];

    controller = StreamController<List<PostModel>>(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          subscriptions.add(
            streams[i].listen(
              (posts) {
                latestPosts[i] = posts;

                final merged = latestPosts
                    .whereType<List<PostModel>>()
                    .expand((items) => items)
                    .toList();

                controller.add(_sortAndLimit(merged, limit));
              },
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Future<void> _deletePostComments(DocumentReference postRef) async {
    while (true) {
      final comments = await postRef.collection('comments').limit(400).get();

      if (comments.docs.isEmpty) break;

      final batch = _db.batch();

      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }

      await batch.commit();
    }
  }

  Future<void> _deletePostNotifications(String postId) async {
    while (true) {
      final notifications = await _db
          .collectionGroup('notifications')
          .where('postId', isEqualTo: postId)
          .limit(400)
          .get();

      if (notifications.docs.isEmpty) break;

      final batch = _db.batch();

      for (final notification in notifications.docs) {
        batch.delete(notification.reference);
      }

      await batch.commit();
    }
  }

  Future<void> _notifyTaggedUsers({
    required List<Map<String, dynamic>> taggedUsers,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String type,
    String? postId,
    String? mediaUrl,
  }) async {
    final sentIds = <String>{};

    for (final taggedUser in taggedUsers) {
      final taggedUserId = taggedUser['uid']?.toString() ?? '';

      if (taggedUserId.isEmpty || !sentIds.add(taggedUserId)) {
        continue;
      }

      await NotificationService().sendNotification(
        toUserId: taggedUserId,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromUserPhotoUrl: fromUserPhotoUrl,
        type: type,
        postId: postId,
        postMediaUrl: mediaUrl,
      );
    }
  }

  Future<void> _syncHashtagCounts({
    required List<String> oldTags,
    required List<String> newTags,
  }) async {
    final oldSet = oldTags.toSet();
    final newSet = newTags.toSet();
    final removed = oldSet.difference(newSet);
    final added = newSet.difference(oldSet);

    if (removed.isEmpty && added.isEmpty) return;

    final batch = _db.batch();
    final now = Timestamp.now();

    for (final tag in added) {
      batch.set(
        _db.collection('hashtags').doc(tag),
        {
          'tag': tag,
          'postCount': FieldValue.increment(1),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    for (final tag in removed) {
      batch.set(
        _db.collection('hashtags').doc(tag),
        {
          'tag': tag,
          'postCount': FieldValue.increment(-1),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<List<PostModel>> _fallbackSearchPosts(
    String cleanQuery, {
    required int limit,
  }) async {
    final posts = await getRecentPosts(limit: limit);

    return posts.where((post) {
      final description = _normalizeForSearch(post.description);
      final username = _normalizeForSearch(post.username);
      final hashtags = _extractHashtags(post.description);

      return description.contains(cleanQuery) ||
          username.contains(cleanQuery) ||
          hashtags.any((tag) => tag.contains(cleanQuery));
    }).toList();
  }

  Future<List<HashtagResult>> _fallbackSearchHashtags(
    String normalizedQuery, {
    required int limit,
  }) async {
    final counts = await _aggregateRecentHashtags(limit: limit);
    final results = counts.entries
        .where((entry) => entry.key.contains(normalizedQuery))
        .map((entry) => HashtagResult(tag: entry.key, postCount: entry.value))
        .toList()
      ..sort((a, b) => b.postCount.compareTo(a.postCount));

    return results;
  }

  Future<List<HashtagResult>> _fallbackTrendingHashtags({
    required int limit,
  }) async {
    final counts = await _aggregateRecentHashtags(limit: limit);
    final results = counts.entries
        .map((entry) => HashtagResult(tag: entry.key, postCount: entry.value))
        .toList()
      ..sort((a, b) => b.postCount.compareTo(a.postCount));

    return results.take(10).toList();
  }

  Future<Map<String, int>> _aggregateRecentHashtags(
      {required int limit}) async {
    final posts = await getRecentPosts(limit: limit);
    final counts = <String, int>{};

    for (final post in posts) {
      for (final tag in _extractHashtags(post.description)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    return counts;
  }

  List<String> _buildSearchKeywords({
    required String description,
    required String username,
  }) {
    final normalizedText = _normalizeForSearch('$description $username');
    final words = RegExp(r'[\p{L}\p{N}_]+', unicode: true)
        .allMatches(normalizedText)
        .map((match) => match.group(0) ?? '')
        .where((word) => word.isNotEmpty);

    final keywords = <String>{};
    for (final word in words) {
      final maxPrefixLength = word.length > 24 ? 24 : word.length;
      for (var length = 1; length <= maxPrefixLength; length++) {
        keywords.add(word.substring(0, length));
      }
      keywords.add(word);
    }

    for (final tag in _extractHashtags(description)) {
      keywords.add(tag);
      final maxPrefixLength = tag.length > 24 ? 24 : tag.length;
      for (var length = 1; length <= maxPrefixLength; length++) {
        keywords.add(tag.substring(0, length));
      }
    }

    return keywords.take(300).toList();
  }

  List<String> _buildQueryTokens(String query) {
    final normalizedQuery = _normalizeForSearch(query);
    final tokens = RegExp(r'[\p{L}\p{N}_]+', unicode: true)
        .allMatches(normalizedQuery)
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();

    if (tokens.isEmpty && normalizedQuery.isNotEmpty) {
      return [normalizedQuery];
    }

    return tokens;
  }

  List<String> _extractHashtags(String text) {
    final matches =
        RegExp(r'(?:^|\s)#([\p{L}\p{N}_]+)', unicode: true).allMatches(text);

    return matches
        .map((match) => _normalizeForSearch(match.group(1) ?? ''))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalizeForSearch(String value) {
    final lower = value.trim().toLowerCase();
    return _foldVietnamese(lower)
        .replaceAll(RegExp(r'[^\p{L}\p{N}_#\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _foldVietnamese(String value) {
    const replacements = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };

    var result = value;
    for (final entry in replacements.entries) {
      for (final char in entry.value.split('')) {
        result = result.replaceAll(char, entry.key);
      }
    }
    return result;
  }
}
