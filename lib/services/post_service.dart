import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/comment_model.dart';
import '../models/post_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

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

      await _db.collection('posts').doc(postId).set(post.toMap());
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
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromDoc(doc);
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

    await _deletePostComments(postRef);
    await _removePostFromSavedLists(postId);
    await postRef.delete();
    try {
      await _deletePostNotifications(postId);
    } catch (_) {
      // Notification cleanup can fail if collection-group rules/indexes are
      // not deployed yet. The post itself is already removed at this point.
    }
  }

  List<PostModel> _sortAndLimit(List<PostModel> posts, int limit) {
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (posts.length <= limit) return posts;
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

  Future<void> _removePostFromSavedLists(String postId) async {
    while (true) {
      final users = await _db
          .collection('users')
          .where('savedPosts', arrayContains: postId)
          .limit(400)
          .get();
      if (users.docs.isEmpty) break;

      final batch = _db.batch();
      for (final user in users.docs) {
        batch.update(user.reference, {
          'savedPosts': FieldValue.arrayRemove([postId]),
        });
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
      if (taggedUserId.isEmpty || !sentIds.add(taggedUserId)) continue;
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
}
