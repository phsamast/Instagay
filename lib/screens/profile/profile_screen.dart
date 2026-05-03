import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../services/post_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final isMyProfile = currentUser?.uid == userId;

    return Scaffold(
      body: StreamBuilder<UserModel>(
        stream: UserService().streamUser(userId),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnap.data!;
          final isFollowing = currentUser?.following.contains(userId) ?? false;

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                title: Text(user.username),
                pinned: true,
              ),
              SliverToBoxAdapter(
                child: _buildProfileHeader(
                  context,
                  user: user,
                  currentUser: currentUser,
                  isMyProfile: isMyProfile,
                  isFollowing: isFollowing,
                ),
              ),
            ],
            body: StreamBuilder<List<PostModel>>(
              stream: PostService().getUserPosts(userId),
              builder: (context, postsSnap) {
                if (!postsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = postsSnap.data!;

                if (posts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Chưa có bài đăng nào'),
                      ],
                    ),
                  );
                }

                // Grid ảnh 3 cột
                return GridView.builder(
                  padding: const EdgeInsets.all(1),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: posts[index].mediaUrl,
                      fit: BoxFit.cover,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, {
        required UserModel user,
        required UserModel? currentUser,
        required bool isMyProfile,
        required bool isFollowing,
      }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 24),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statColumn('Bài đăng', '0'),
                    _statColumn('Followers', '${user.followers.length}'),
                    _statColumn('Following', '${user.following.length}'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            user.username,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(user.bio, style: const TextStyle(fontSize: 14)),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: isMyProfile
                ? OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Chỉnh sửa trang cá nhân'),
            )
                : ElevatedButton(
              onPressed: () {
                if (currentUser == null) return;
                if (isFollowing) {
                  UserService().unfollowUser(
                    currentUserId: currentUser.uid,
                    targetUserId: user.uid,
                  );
                } else {
                  UserService().followUser(
                    currentUserId: currentUser.uid,
                    targetUserId: user.uid,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isFollowing ? Colors.grey[200] : Colors.blue,
                foregroundColor:
                isFollowing ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(isFollowing ? 'Đang theo dõi' : 'Theo dõi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}