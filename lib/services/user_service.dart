import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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
    await _db.collection('users').doc(userId).update(data);
  }


  Stream<UserModel> streamUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map(UserModel.fromDoc);
  }
}