import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String toUserId;
  final String fromUserId;
  final String fromUsername;
  final String fromUserPhotoUrl;
  final String type; // 'like', 'comment', 'follow'
  final String? postId;
  final String? postMediaUrl;
  final String? commentText;
  final Timestamp timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.toUserId,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromUserPhotoUrl,
    required this.type,
    this.postId,
    this.postMediaUrl,
    this.commentText,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      toUserId: data['toUserId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromUserPhotoUrl: data['fromUserPhotoUrl'] ?? '',
      type: data['type'] ?? '',
      postId: data['postId'],
      postMediaUrl: data['postMediaUrl'],
      commentText: data['commentText'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toUserId': toUserId,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'type': type,
      'postId': postId,
      'postMediaUrl': postMediaUrl,
      'commentText': commentText,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}
