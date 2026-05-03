import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import 'storage_service.dart';
class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();


  Future<String> uploadPost({
    required File imageFile,
    required String description,
    required String userId,
    required String username,
    required String userPhotoUrl,
  }) async {
    try {
      final postId = _uuid.v4();


      final mediaUrl = await StorageService.uploadImage(imageFile);
      if (mediaUrl == null) return 'Lỗi upload ảnh';


      final post = PostModel(
        postId: postId,
        ownerId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        mediaUrl: mediaUrl,
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


  Stream<List<PostModel>> getAllPosts() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
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


  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final ref = _db.collection('posts').doc(postId);
    if (isLiked) {
      // Bỏ like
      await ref.update({'likes.$userId': FieldValue.delete()});
    } else {
      // Like
      await ref.update({'likes.$userId': true});
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