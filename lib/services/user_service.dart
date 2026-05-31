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
    final currentUserSnap =
        await _db.collection('users').doc(currentUserId).get();
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
    final normalizedQuery = _normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return [];

    try {
      final indexedResult = await _db
          .collection('users')
          .where('usernameKeywords', arrayContains: normalizedQuery)
          .limit(20)
          .get();

      final users = indexedResult.docs.map(UserModel.fromDoc).toList();
      if (users.isNotEmpty) return users;
    } catch (_) {
      // Older user documents may not have usernameKeywords yet.
    }

    final result = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: normalizedQuery)
        .where('username', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(20)
        .get();
    return result.docs.map(UserModel.fromDoc).toList();
  }

  Future<List<UserModel>> getSuggestedUsers({
    required String currentUserId,
    List<dynamic> following = const [],
  }) async {
    final snap =
        await _db.collection('users').orderBy('username').limit(60).get();
    final followingIds = following.map((id) => id.toString()).toSet();
    final users = snap.docs
        .map(UserModel.fromDoc)
        .where(
          (user) =>
              user.uid != currentUserId && !followingIds.contains(user.uid),
        )
        .toList();

    users.sort((a, b) => b.followers.length.compareTo(a.followers.length));
    return users.take(10).toList();
  }

  Future<List<UserModel>> getShareableUsers(String currentUserId) async {
    final snap =
        await _db.collection('users').orderBy('username').limit(100).get();

    return snap.docs
        .map(UserModel.fromDoc)
        .where((user) => user.uid != currentUserId)
        .toList();
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
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        throw StateError('User document does not exist: $userId');
      }
      return UserModel.fromDoc(doc);
    });
  }

  Future<List<UserModel>> getUsersByUids(List<String> uids) async {
    if (uids.isEmpty) return [];

    // Firestore whereIn supports up to 30 elements.
    // For simplicity, we fetch in chunks if needed, but for followers/following
    // we might just fetch the first 30 or implement a more robust chunking.
    // Let's implement chunking.

    List<UserModel> users = [];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk =
          uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snap =
          await _db.collection('users').where('uid', whereIn: chunk).get();
      users.addAll(snap.docs.map(UserModel.fromDoc));
    }

    return users;
  }

  List<String> buildUsernameKeywords(String username) {
    final normalized = _normalizeForSearch(username);
    if (normalized.isEmpty) return [];

    final keywords = <String>{};
    final maxPrefixLength = normalized.length > 24 ? 24 : normalized.length;
    for (var length = 1; length <= maxPrefixLength; length++) {
      keywords.add(normalized.substring(0, length));
    }
    keywords.add(normalized);
    return keywords.toList();
  }

  String _normalizeForSearch(String value) {
    final lower = value.trim().toLowerCase();
    return _foldVietnamese(lower)
        .replaceAll(RegExp(r'[^\p{L}\p{N}_]+', unicode: true), '')
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
