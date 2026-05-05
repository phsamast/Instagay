import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<void> sendNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String type, // 'like', 'comment', 'follow'
    String? postId,
    String? postMediaUrl,
    String? commentText,
  }) async {
    // Không tự thông báo cho chính mình
    if (toUserId == fromUserId) return;

    final id = _uuid.v4();
    final notification = NotificationModel(
      id: id,
      toUserId: toUserId,
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      fromUserPhotoUrl: fromUserPhotoUrl,
      type: type,
      postId: postId,
      postMediaUrl: postMediaUrl,
      commentText: commentText,
      timestamp: Timestamp.now(),
    );

    await _db
        .collection('users')
        .doc(toUserId)
        .collection('notifications')
        .doc(id)
        .set(notification.toMap());
  }

  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(NotificationModel.fromDoc).toList());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
