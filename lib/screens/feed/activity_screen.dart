import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../profile/profile_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
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

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
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
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: '${notif.fromUsername} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: _getNotificationText(notif.type),
                      ),
                      if (notif.type == 'comment' && notif.commentText != null)
                        TextSpan(
                          text: ': "${notif.commentText}"',
                        ),
                    ],
                  ),
                ),
                subtitle: Text(
                  timeago.format(notif.timestamp.toDate(), locale: 'vi'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: _buildTrailing(notif),
                onTap: () {
                  // Đánh dấu đã đọc
                  if (!notif.isRead) {
                    NotificationService().markAsRead(user.uid, notif.id);
                  }
                  // TODO: Chuyển hướng tới bài viết hoặc profile tùy loại
                },
              );
            },
          );
        },
      ),
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
      default:
        return 'đã tương tác với bạn.';
    }
  }

  Widget? _buildTrailing(NotificationModel notif) {
    if (notif.type == 'follow') {
      return ElevatedButton(
        onPressed: () {
          // TODO: Toggle follow back
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minimumSize: Size.zero,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Theo dõi'),
      );
    } else if (notif.postMediaUrl != null && notif.postMediaUrl!.isNotEmpty) {
      return SizedBox(
        width: 40,
        height: 40,
        child: CachedNetworkImage(
          imageUrl: notif.postMediaUrl!,
          fit: BoxFit.cover,
        ),
      );
    }
    return null;
  }
}
