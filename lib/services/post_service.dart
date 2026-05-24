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
    final queryList = followingAndMe.take(10).toList();

    return _db
        .collection('posts')
        .where('ownerId', whereIn: queryList)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromDoc).toList());
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
    await _db.collection('posts').doc(postId).delete();
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
