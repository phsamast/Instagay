import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';
import '../../services/story_service.dart';
import '../../models/post_model.dart';
import '../../models/story_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/story_bar.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MXH Clone',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              context.read<UserProvider>().clearUser();
              await AuthService().logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: StreamBuilder<List<StoryModel>>(
                stream: StoryService().getActiveStories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return StoryBar(stories: snapshot.data!);
                },
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            StreamBuilder<List<PostModel>>(
              stream: PostService().getAllPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có bài đăng nào',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final posts = snapshot.data!;
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return PostCard(post: posts[index]);
                    },
                    childCount: posts.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}