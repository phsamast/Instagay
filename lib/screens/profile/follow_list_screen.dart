import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String title;
  final List userIds;

  const FollowListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: userIds.isEmpty
          ? const Center(
              child: Text(
                'Chưa có ai ở đây',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: userIds.length,
              itemBuilder: (context, index) {
                final uid = userIds[index];
                return FutureBuilder<UserModel?>(
                  // Tạm thời fetch single user, nếu nhiều có thể fetch batch để tối ưu
                  future: UserService().streamUser(uid).first,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.grey),
                        title: Text('Đang tải...'),
                      );
                    }
                    final user = snapshot.data!;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: user.uid),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
