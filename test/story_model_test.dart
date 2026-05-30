import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clone_mxh/models/story_model.dart';

void main() {
  test('StoryModel exposes video state from mediaType', () {
    final story = StoryModel(
      storyId: 'story-1',
      ownerId: 'user-1',
      username: 'tester',
      userPhotoUrl: '',
      mediaUrl: 'https://example.com/video.mp4',
      mediaType: 'video',
      timestamp: Timestamp.fromMillisecondsSinceEpoch(1000),
      viewers: const [],
    );

    expect(story.isVideo, isTrue);
    expect(story.toMap()['mediaType'], 'video');
  });
}
