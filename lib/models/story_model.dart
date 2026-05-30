import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String storyId;
  final String ownerId;
  final String username;
  final String userPhotoUrl;
  final String mediaUrl;
  final String mediaType;
  final Timestamp timestamp;
  final List<String> viewers;
  final List<Map<String, dynamic>> taggedUsers;

  StoryModel({
    required this.storyId,
    required this.ownerId,
    required this.username,
    required this.userPhotoUrl,
    required this.mediaUrl,
    this.mediaType = 'image',
    required this.timestamp,
    required this.viewers,
    this.taggedUsers = const [],
  });

  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      storyId: data['storyId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      viewers: List<String>.from(data['viewers'] ?? []),
      taggedUsers: List<Map<String, dynamic>>.from(
        (data['taggedUsers'] ?? []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'ownerId': ownerId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': timestamp,
      'viewers': viewers,
      'taggedUsers': taggedUsers,
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final storyTime = timestamp.toDate();
    return now.difference(storyTime).inHours >= 24;
  }

  bool get isVideo => mediaType == 'video';
}
