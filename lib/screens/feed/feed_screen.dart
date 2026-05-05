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
import 'activity_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _postLimit = 5;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Khi cuộn gần cuối trang, tăng số lượng bài viết lấy về
      setState(() {
        _postLimit += 5;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final followingAndMe = [user.uid, ...user.following];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Instagay',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: () {
              // TODO: Điều hướng sang Chat
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _postLimit = 5;
          });
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          controller: _scrollController,
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
              stream: PostService().getFeedPosts(followingAndMe, _postLimit),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _postLimit == 5) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Fallback: nếu following không có bài viết nào, hiển thị Khám phá
                  return _buildFallbackExplore();
                }

                final posts = snapshot.data!;
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index == posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return PostCard(post: posts[index]);
                    },
                    childCount: posts.length + (posts.length >= _postLimit ? 1 : 0),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackExplore() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Chào mừng đến với Instagay',
              style: TextStyle(color: Colors.grey[800], fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy theo dõi một vài người để xem bài đăng của họ.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}