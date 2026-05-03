import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/story_model.dart';
import '../providers/user_provider.dart';
import '../services/story_service.dart';
import '../screens/feed/story_view_screen.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;

  const StoryBar({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final isViewed = currentUser != null &&
              story.viewers.contains(currentUser.uid);

          return GestureDetector(
            onTap: () {
              // Đánh dấu đã xem
              if (currentUser != null) {
                StoryService().markStoryViewed(
                  storyId: story.storyId,
                  viewerId: currentUser.uid,
                );
              }
              // Mở story
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewScreen(
                    stories: stories,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  // Vòng tròn gradient = chưa xem, xám = đã xem
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isViewed
                          ? null
                          : const LinearGradient(
                        colors: [
                          Colors.purple,
                          Colors.pink,
                          Colors.orange,
                        ],
                      ),
                      color: isViewed ? Colors.grey[300] : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: story.userPhotoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(story.userPhotoUrl)
                            : null,
                        child: story.userPhotoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Tên user
                  SizedBox(
                    width: 64,
                    child: Text(
                      story.username,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}