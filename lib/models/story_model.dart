import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String storyId;
  final String ownerId;
  final String username;
  final String userPhotoUrl;
  final String mediaUrl;
  final Timestamp timestamp;
  final List<String> viewers;

  StoryModel({
    required this.storyId,
    required this.ownerId,
    required this.username,
    required this.userPhotoUrl,
    required this.mediaUrl,
    required this.timestamp,
    required this.viewers,
  });

  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      storyId: data['storyId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'ownerId': ownerId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
      'viewers': viewers,
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final storyTime = timestamp.toDate();
    return now.difference(storyTime).inHours >= 24;
  }
}