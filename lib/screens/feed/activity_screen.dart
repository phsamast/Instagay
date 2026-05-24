import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/story_service.dart';
import '../../widgets/post_card.dart';
import '../profile/profile_screen.dart';
import 'comment_screen.dart';
import 'story_view_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService().getNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'Không có thông báo nào',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                tileColor:
                    notif.isRead ? null : Colors.blue.withValues(alpha: 0.04),
                leading: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: notif.fromUserId),
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: notif.fromUserPhotoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(notif.fromUserPhotoUrl)
                        : null,
                    child: notif.fromUserPhotoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, height: 1.25),
                    children: [
                      TextSpan(
                        text: '${notif.fromUsername} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: _getNotificationText(notif.type)),
                      if (notif.type == 'comment' && notif.commentText != null)
                        TextSpan(text: ': "${notif.commentText}"'),
                    ],
                  ),
                ),
                subtitle: Text(
                  timeago.format(notif.timestamp.toDate(), locale: 'vi'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: _buildTrailing(notif),
                onTap: () => _handleNotificationTap(
                  context: context,
                  currentUserId: user.uid,
                  notif: notif,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap({
    required BuildContext context,
    required String currentUserId,
    required NotificationModel notif,
  }) async {
    if (!notif.isRead) {
      await NotificationService().markAsRead(currentUserId, notif.id);
    }
    if (!context.mounted) return;

    switch (notif.type) {
      case 'follow':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: notif.fromUserId),
          ),
        );
        return;
      case 'comment':
        await _openPostComments(context, notif);
        return;
      case 'like':
      case 'tag_post':
        await _openPostDetail(context, notif);
        return;
      case 'tag_story':
        await _openStory(context, notif);
        return;
      default:
        if (notif.postId != null && notif.postId!.isNotEmpty) {
          await _openPostDetail(context, notif);
        }
    }
  }

  Future<void> _openPostDetail(
    BuildContext context,
    NotificationModel notif,
  ) async {
    final post = await _loadPostOrShowError(context, notif.postId);
    if (post == null || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Bài viết')),
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      ),
    );
  }

  Future<void> _openPostComments(
    BuildContext context,
    NotificationModel notif,
  ) async {
    final post = await _loadPostOrShowError(context, notif.postId);
    if (post == null || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentScreen(
          post: post,
          highlightedCommentId: notif.commentId,
          highlightedUserId: notif.fromUserId,
        ),
      ),
    );
  }

  Future<PostModel?> _loadPostOrShowError(
    BuildContext context,
    String? postId,
  ) async {
    if (postId == null || postId.isEmpty) {
      _showMessage(context, 'Không tìm thấy bài viết');
      return null;
    }

    final post = await PostService().getPostById(postId);
    if (post == null && context.mounted) {
      _showMessage(context, 'Bài viết không còn tồn tại');
    }
    return post;
  }

  Future<void> _openStory(BuildContext context, NotificationModel notif) async {
    final storyId = notif.storyId;
    if (storyId == null || storyId.isEmpty) {
      _showMessage(context, 'Không tìm thấy story');
      return;
    }

    final story = await StoryService().getStoryById(storyId);
    if (!context.mounted) return;
    if (story == null || story.isExpired) {
      _showMessage(context, 'Story đã hết hạn hoặc không còn tồn tại');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(stories: [story], initialIndex: 0),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _getNotificationText(String type) {
    switch (type) {
      case 'like':
        return 'đã thích bài viết của bạn.';
      case 'comment':
        return 'đã bình luận về bài viết của bạn';
      case 'follow':
        return 'đã bắt đầu theo dõi bạn.';
      case 'tag_post':
        return 'đã nhắc đến bạn trong một bài viết.';
      case 'tag_story':
        return 'đã nhắc đến bạn trong story.';
      default:
        return 'đã tương tác với bạn.';
    }
  }

  Widget? _buildTrailing(NotificationModel notif) {
    if (notif.type == 'follow') {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minimumSize: Size.zero,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Theo dõi'),
      );
    }

    if (notif.postMediaUrl != null && notif.postMediaUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: CachedNetworkImage(
            imageUrl: notif.postMediaUrl!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return null;
  }
}
