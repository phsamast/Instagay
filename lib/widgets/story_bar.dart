import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/story_model.dart';
import '../providers/user_provider.dart';
import '../services/story_service.dart';
import '../screens/feed/story_view_screen.dart';
import '../screens/upload/upload_screen.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;

  const StoryBar({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    if (currentUser == null) return const SizedBox.shrink();

    final otherStories =
        stories.where((s) => s.ownerId != currentUser.uid).toList();
    final myStories =
        stories.where((s) => s.ownerId == currentUser.uid).toList();
    final hasMyStories = myStories.isNotEmpty;
    final itemCount = 1 + otherStories.length;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isViewed = hasMyStories &&
                myStories.every((s) => s.viewers.contains(currentUser.uid));

            return GestureDetector(
              onTap: () {
                if (hasMyStories) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewScreen(
                        stories: myStories,
                        initialIndex: 0,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UploadScreen(initialTab: 1),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: !hasMyStories
                                ? null
                                : (isViewed
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFFFBAA47),
                                          Color(0xFFD91A5F),
                                          Color(0xFF8B26B1),
                                        ],
                                      )),
                            color: (hasMyStories && isViewed)
                                ? Colors.grey[300]
                                : Colors.transparent,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundImage: currentUser.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      currentUser.photoUrl,
                                    )
                                  : null,
                              child: currentUser.photoUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          ),
                        ),
                        if (!hasMyStories)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const SizedBox(
                      width: 64,
                      child: Text(
                        'Tin của bạn',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final story = otherStories[index - 1];
          final isViewed = story.viewers.contains(currentUser.uid);

          return GestureDetector(
            onTap: () {
              StoryService().markStoryViewed(
                storyId: story.storyId,
                viewerId: currentUser.uid,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewScreen(
                    stories: otherStories,
                    initialIndex: index - 1,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isViewed
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFFFBAA47),
                                Color(0xFFD91A5F),
                                Color(0xFF8B26B1),
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
