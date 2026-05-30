import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clone_mxh/models/post_model.dart';

void main() {
  test('PostModel exposes media helpers and like state', () {
    final post = PostModel(
      postId: 'post-1',
      ownerId: 'user-1',
      username: 'tester',
      userPhotoUrl: '',
      mediaUrls: ['https://example.com/one.jpg', 'https://example.com/two.jpg'],
      mediaType: 'image',
      description: 'hello',
      likes: {'user-2': true},
      timestamp: Timestamp.fromMillisecondsSinceEpoch(1000),
    );

    expect(post.mediaUrl, 'https://example.com/one.jpg');
    expect(post.isVideo, isFalse);
    expect(post.isMultiple, isTrue);
    expect(post.likeCount, 1);
    expect(post.isLikedBy('user-2'), isTrue);
    expect(post.isLikedBy('user-3'), isFalse);

    final updatedPost = post.copyWith(
      description: 'updated',
      taggedUsers: [
        {'uid': 'user-3', 'username': 'friend', 'photoUrl': ''},
      ],
    );

    expect(updatedPost.postId, post.postId);
    expect(updatedPost.description, 'updated');
    expect(updatedPost.taggedUsers.first['uid'], 'user-3');
  });
}
