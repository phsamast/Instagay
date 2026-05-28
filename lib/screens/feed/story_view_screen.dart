import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/story_model.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _startStory();
  }

  void _startStory() {
    _progressController.forward(from: 0);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          // Chạm trái → story trước, chạm phải → story tiếp theo
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            Center(
              child: CachedNetworkImage(
                imageUrl: story.mediaUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: index == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (_, __) => LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.4),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                    minHeight: 3,
                                  ),
                                )
                              : LinearProgressIndicator(
                                  value: index < _currentIndex ? 1.0 : 0.0,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.4),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                  minHeight: 3,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ========== HEADER: Avatar + tên + thời gian ==========
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 12, right: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: story.userPhotoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(story.userPhotoUrl)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeago.format(story.timestamp.toDate(),
                              locale: 'vi'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Nút đóng
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
