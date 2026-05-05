import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String ownerId;
  final String username;
  final String userPhotoUrl;
  final List<String> mediaUrls; // Hỗ trợ nhiều ảnh/video
  final String mediaType; // 'image' hoặc 'video'
  final String description;
  final Map<String, dynamic> likes;
  final Timestamp timestamp;

  PostModel({
    required this.postId,
    required this.ownerId,
    required this.username,
    required this.userPhotoUrl,
    required this.mediaUrls,
    required this.mediaType,
    required this.description,
    required this.likes,
    required this.timestamp,
  });

  String get mediaUrl => mediaUrls.isNotEmpty ? mediaUrls.first : '';
  bool get isVideo => mediaType == 'video';
  bool get isMultiple => mediaUrls.length > 1;

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    List<String> urls = [];
    if (data['mediaUrls'] != null) {
      urls = List<String>.from(data['mediaUrls']);
    } else if (data['mediaUrl'] != null) {
      urls = [data['mediaUrl']];
    }
    return PostModel(
      postId: data['postId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      mediaUrls: urls,
      mediaType: data['mediaType'] ?? 'image',
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
      'mediaUrls': mediaUrls,
      'mediaType': mediaType,
      'description': description,
      'likes': likes,
      'timestamp': timestamp,
    };
  }

  int get likeCount => likes.length;
  bool isLikedBy(String userId) => likes.containsKey(userId);
}