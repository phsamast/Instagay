import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String ownerId;
  final String username;
  final String userPhotoUrl;
  final String mediaUrl;
  final String description;
  final Map<String, dynamic> likes; // {'userId': true}
  final Timestamp timestamp;

  PostModel({
    required this.postId,
    required this.ownerId,
    required this.username,
    required this.userPhotoUrl,
    required this.mediaUrl,
    required this.description,
    required this.likes,
    required this.timestamp,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: data['postId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      description: data['description'] ?? '',
      likes: Map<String, dynamic>.from(data['likes'] ?? {}),
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'ownerId': ownerId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'mediaUrl': mediaUrl,
      'description': description,
      'likes': likes,
      'timestamp': timestamp,
    };
  }

  int get likeCount => likes.length;

  bool isLikedBy(String userId) => likes.containsKey(userId);
}