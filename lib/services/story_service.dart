import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/story_model.dart';
import 'storage_service.dart';
class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();


  Future<String> uploadStory({
    required File imageFile,
    required String userId,
    required String username,
    required String userPhotoUrl,
  }) async {
    try {
      final storyId = _uuid.v4();

      final mediaUrl = await StorageService.uploadImage(imageFile);
      if (mediaUrl == null) return 'Lỗi upload ảnh';

      final story = StoryModel(
        storyId: storyId,
        ownerId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        mediaUrl: mediaUrl,
        timestamp: Timestamp.now(),
        viewers: [],
      );

      await _db.collection('stories').doc(storyId).set(story.toMap());
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }


  Stream<List<StoryModel>> getActiveStories() {
    // Lấy stories trong 24 giờ qua
    final yesterday = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    return _db
        .collection('stories')
        .where('timestamp', isGreaterThan: yesterday)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(StoryModel.fromDoc).toList());
  }


  Future<void> markStoryViewed({
    required String storyId,
    required String viewerId,
  }) async {
    await _db.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([viewerId]),
    });
  }
}