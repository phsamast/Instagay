import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../services/post_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/post_card.dart';
import '../../main.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final isMyProfile = currentUser?.uid == userId;
    final tabCount = isMyProfile ? 2 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        body: StreamBuilder<UserModel>(
          stream: UserService().streamUser(userId),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = userSnap.data!;
            final isFollowing = currentUser?.following.contains(userId) ?? false;

            return StreamBuilder<List<PostModel>>(
              stream: PostService().getUserPosts(userId),
              builder: (context, postsSnap) {
                if (!postsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = postsSnap.data!;

                return NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverAppBar(
                      title: Text(user.username),
                      pinned: true,
                      actions: [
                        if (isMyProfile)
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () async {
                              // Đăng xuất
                              await AuthService().logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const MyApp()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(
                        context,
                        user: user,
                        currentUser: currentUser,
                        isMyProfile: isMyProfile,
                        isFollowing: isFollowing,
                        postCount: posts.length,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            const Tab(icon: Icon(Icons.grid_on)),
                            if (isMyProfile)
                              const Tab(icon: Icon(Icons.bookmark_border)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      _buildPostsGrid(context, posts),
                      if (isMyProfile) _buildSavedPostsGrid(context, user.savedPosts),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostsGrid(BuildContext context, List<PostModel> posts) {
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
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Bài viết')),
                  body: SingleChildScrollView(child: PostCard(post: post)),
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: post.mediaUrl,
                fit: BoxFit.cover,
              ),
              if (post.isVideo)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.play_arrow, color: Colors.white),
                )
              else if (post.isMultiple)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.collections, color: Colors.white, size: 20),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedPostsGrid(BuildContext context, List savedIds) {
    return FutureBuilder<List<PostModel>>(
      future: PostService().getSavedPosts(savedIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('Chưa lưu bài viết nào'),
              ],
            ),
          );
        }
        return _buildPostsGrid(context, posts);
      },
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, {
        required UserModel user,
        required UserModel? currentUser,
        required bool isMyProfile,
        required bool isFollowing,
        required int postCount,
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
                    _statColumn('Bài đăng', '$postCount'),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            title: 'Người theo dõi',
                            userIds: user.followers,
                          ),
                        ),
                      ),
                      child: _statColumn('Followers', '${user.followers.length}'),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            title: 'Đang theo dõi',
                            userIds: user.following,
                          ),
                        ),
                      ),
                      child: _statColumn('Following', '${user.following.length}'),
                    ),
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}