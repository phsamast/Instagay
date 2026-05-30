import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/story_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<String> uploadStory({
    required File mediaFile,
    required String mediaType,
    required String userId,
    required String username,
    required String userPhotoUrl,
    List<Map<String, dynamic>> taggedUsers = const [],
    void Function(double progress)? onProgress,
  }) async {
    try {
      final storyId = _uuid.v4();
      final mediaUrl = mediaType == 'video'
          ? await StorageService.uploadVideo(mediaFile, onProgress: onProgress)
          : await StorageService.uploadImage(mediaFile, onProgress: onProgress);

      if (mediaUrl == null) return 'Lỗi upload story';

      final story = StoryModel(
        storyId: storyId,
        ownerId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        timestamp: Timestamp.now(),
        viewers: [],
        taggedUsers: taggedUsers,
      );

      await _db.collection('stories').doc(storyId).set(story.toMap());
      await _notifyTaggedUsers(
        taggedUsers: taggedUsers,
        fromUserId: userId,
        fromUsername: username,
        fromUserPhotoUrl: userPhotoUrl,
        storyId: storyId,
        mediaUrl: mediaUrl,
      );
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<StoryModel>> getActiveStories() {
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

  Future<StoryModel?> getStoryById(String storyId) async {
    final doc = await _db.collection('stories').doc(storyId).get();
    if (!doc.exists) return null;
    return StoryModel.fromDoc(doc);
  }

  Future<void> markStoryViewed({
    required String storyId,
    required String viewerId,
  }) async {
    await _db.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([viewerId]),
    });
  }

  Future<void> deleteStory(String storyId) async {
    await _db.collection('stories').doc(storyId).delete();
  }

  Future<List<UserModel>> getStoryViewers(List<String> viewerIds) async {
    if (viewerIds.isEmpty) return [];

    final viewers = <UserModel>[];
    for (var i = 0; i < viewerIds.length; i += 30) {
      final chunk = viewerIds.sublist(
        i,
        i + 30 > viewerIds.length ? viewerIds.length : i + 30,
      );
      final snap =
          await _db.collection('users').where('uid', whereIn: chunk).get();
      viewers.addAll(snap.docs.map(UserModel.fromDoc));
    }

    return viewers;
  }

  Future<void> _notifyTaggedUsers({
    required List<Map<String, dynamic>> taggedUsers,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String storyId,
    required String mediaUrl,
  }) async {
    final sentIds = <String>{};
    for (final taggedUser in taggedUsers) {
      final taggedUserId = taggedUser['uid']?.toString() ?? '';
      if (taggedUserId.isEmpty || !sentIds.add(taggedUserId)) continue;
      await NotificationService().sendNotification(
        toUserId: taggedUserId,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromUserPhotoUrl: fromUserPhotoUrl,
        type: 'tag_story',
        storyId: storyId,
        postMediaUrl: mediaUrl,
      );
    }
  }
}
