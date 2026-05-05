import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ==================== ĐĂNG BÀI (ảnh hoặc video) ====================
  Future<String> uploadPost({
    required List<File> mediaFiles, // Hỗ trợ nhiều file
    required String mediaType,      // 'image' hoặc 'video'
    required String description,
    required String userId,
    required String username,
    required String userPhotoUrl,
  }) async {
    try {
      final postId = _uuid.v4();
      List<String> mediaUrls = [];

      if (mediaType == 'video') {
        // Upload video
        final url = await StorageService.uploadVideo(mediaFiles.first);
        if (url == null) return 'Lỗi upload video';
        mediaUrls = [url];
      } else {
        // Upload nhiều ảnh
        mediaUrls = await StorageService.uploadMultipleImages(mediaFiles);
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
      );

      await _db.collection('posts').doc(postId).set(post.toMap());
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== LẤY FEED ====================
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
    // Firebase whereIn limit is 10
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

  Future<List<PostModel>> getSavedPosts(List savedIds) async {
    if (savedIds.isEmpty) return [];
    final List<PostModel> posts = [];
    for (var i = 0; i < savedIds.length; i += 10) {
      final chunk = savedIds.skip(i).take(10).toList();
      final snap = await _db.collection('posts').where('postId', whereIn: chunk).get();
      posts.addAll(snap.docs.map(PostModel.fromDoc));
    }
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return posts;
  }

  // ==================== LIKE ====================
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
      
      // Gửi thông báo Like
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
            postMediaUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
          );
        }
      }
    }
  }

  // ==================== COMMENT ====================
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

    // Gửi thông báo Comment
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
}