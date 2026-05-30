import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String ownerId;
  final String username;
  final String userPhotoUrl;
  final List<String> mediaUrls;
  final String mediaType;
  final String description;
  final Map<String, dynamic> likes;
  final Timestamp timestamp;
  final List<Map<String, dynamic>> taggedUsers;

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
    this.taggedUsers = const [],
  });

  String get mediaUrl => mediaUrls.isNotEmpty ? mediaUrls.first : '';
  bool get isVideo => mediaType == 'video';
  bool get isMultiple => mediaUrls.length > 1;

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    var urls = <String>[];
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
      taggedUsers: List<Map<String, dynamic>>.from(
        (data['taggedUsers'] ?? []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      ),
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
      'taggedUsers': taggedUsers,
    };
  }

  PostModel copyWith({
    String? postId,
    String? ownerId,
    String? username,
    String? userPhotoUrl,
    List<String>? mediaUrls,
    String? mediaType,
    String? description,
    Map<String, dynamic>? likes,
    Timestamp? timestamp,
    List<Map<String, dynamic>>? taggedUsers,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      ownerId: ownerId ?? this.ownerId,
      username: username ?? this.username,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      description: description ?? this.description,
      likes: likes ?? this.likes,
      timestamp: timestamp ?? this.timestamp,
      taggedUsers: taggedUsers ?? this.taggedUsers,
    );
  }

  int get likeCount => likes.length;
  bool isLikedBy(String userId) => likes.containsKey(userId);
}
