import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/story_model.dart';
import '../providers/user_provider.dart';
import '../screens/feed/story_view_screen.dart';
import '../screens/upload/upload_screen.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;

  const StoryBar({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    if (currentUser == null) return const SizedBox.shrink();

    final groupedStories = _groupStoriesByUser(stories);
    final myStories = groupedStories.remove(currentUser.uid) ?? [];
    final otherGroups = groupedStories.values.toList()
      ..sort((a, b) => b.first.timestamp.compareTo(a.first.timestamp));

    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: 1 + otherGroups.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryAvatarItem(
              label: 'Tin của bạn',
              photoUrl: currentUser.photoUrl,
              hasStories: myStories.isNotEmpty,
              isViewed: myStories.isNotEmpty,
              showAddButton: true,
              onTap: () {
                if (myStories.isEmpty) {
                  _openStoryComposer(context);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewScreen(
                      stories: myStories,
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              onAddTap: () => _openStoryComposer(context),
            );
          }

          final group = otherGroups[index - 1];
          final firstStory = group.first;
          final isViewed = group.every(
            (story) => story.viewers.contains(currentUser.uid),
          );

          return _StoryAvatarItem(
            label: firstStory.username,
            photoUrl: firstStory.userPhotoUrl,
            hasStories: true,
            isViewed: isViewed,
            showAddButton: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewScreen(
                    stories: group,
                    initialIndex: _firstUnviewedIndex(group, currentUser.uid),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<StoryModel>> _groupStoriesByUser(List<StoryModel> stories) {
    final groups = <String, List<StoryModel>>{};
    for (final story in stories) {
      groups.putIfAbsent(story.ownerId, () => []).add(story);
    }

    for (final group in groups.values) {
      group.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return groups;
  }

  int _firstUnviewedIndex(List<StoryModel> stories, String userId) {
    final index =
        stories.indexWhere((story) => !story.viewers.contains(userId));
    return index == -1 ? 0 : index;
  }

  void _openStoryComposer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadScreen(initialTab: 1)),
    );
  }
}

class _StoryAvatarItem extends StatelessWidget {
  final String label;
  final String photoUrl;
  final bool hasStories;
  final bool isViewed;
  final bool showAddButton;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  const _StoryAvatarItem({
    required this.label,
    required this.photoUrl,
    required this.hasStories,
    required this.isViewed,
    required this.showAddButton,
    required this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStories && !isViewed
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFBAA47),
                              Color(0xFFD91A5F),
                              Color(0xFF8B26B1),
                            ],
                          )
                        : null,
                    color: hasStories && isViewed
                        ? Colors.grey.shade300
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
                      backgroundImage: photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                  ),
                ),
                if (showAddButton)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAddTap,
                      child: Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 68,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
