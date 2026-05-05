import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;


  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {

    await _db.collection('users').doc(currentUserId).update({
      'following': FieldValue.arrayUnion([targetUserId]),
    });

    await _db.collection('users').doc(targetUserId).update({
      'followers': FieldValue.arrayUnion([currentUserId]),
    });

    // Gửi thông báo Follow
    final currentUserSnap = await _db.collection('users').doc(currentUserId).get();
    if (currentUserSnap.exists) {
      final currentUserData = currentUserSnap.data() as Map<String, dynamic>;
      NotificationService().sendNotification(
        toUserId: targetUserId,
        fromUserId: currentUserId,
        fromUsername: currentUserData['username'] ?? '',
        fromUserPhotoUrl: currentUserData['photoUrl'] ?? '',
        type: 'follow',
      );
    }
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _db.collection('users').doc(currentUserId).update({
      'following': FieldValue.arrayRemove([targetUserId]),
    });
    await _db.collection('users').doc(targetUserId).update({
      'followers': FieldValue.arrayRemove([currentUserId]),
    });
  }


  Future<void> savePost(String userId, String postId) async {
    await _db.collection('users').doc(userId).update({
      'savedPosts': FieldValue.arrayUnion([postId]),
    });
  }

  Future<void> unsavePost(String userId, String postId) async {
    await _db.collection('users').doc(userId).update({
      'savedPosts': FieldValue.arrayRemove([postId]),
    });
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final result = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
    return result.docs.map(UserModel.fromDoc).toList();
  }


  Future<void> updateProfile({
    required String userId,
    required String bio,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{'bio': bio};
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    // Cập nhật profile user
    await _db.collection('users').doc(userId).update(data);

    // Cập nhật ảnh đại diện trên tất cả bài đăng cũ
    if (photoUrl != null) {
      final posts = await _db
          .collection('posts')
          .where('ownerId', isEqualTo: userId)
          .get();

      final batch = _db.batch();
      for (final post in posts.docs) {
        batch.update(post.reference, {'userPhotoUrl': photoUrl});
      }
      await batch.commit();
    }
  }


  Stream<UserModel> streamUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map(UserModel.fromDoc);
  }
}