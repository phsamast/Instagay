import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../models/story_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/story_service.dart';
import '../upload/upload_screen.dart';

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
  late final AnimationController _progressController;
  final _replyController = TextEditingController();
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Set<String> _markedViewedStoryIds = {};

  VideoPlayerController? _activeVideoController;
  bool _isSendingReply = false;

  StoryModel get _story => widget.stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextStory();
      });
    _showCurrentStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showCurrentStory() async {
    _progressController.stop();
    _progressController.reset();
    _activeVideoController?.pause();
    _activeVideoController = null;

    _markCurrentStoryViewed();

    if (_story.isVideo) {
      final controller = await _getVideoController(_story);
      if (!mounted || _story.storyId != widget.stories[_currentIndex].storyId) {
        return;
      }
      _activeVideoController = controller;
      await controller.seekTo(Duration.zero);
      await controller.play();
      _progressController.duration = controller.value.duration == Duration.zero
          ? const Duration(seconds: 10)
          : controller.value.duration;
    } else {
      _progressController.duration = const Duration(seconds: 7);
    }

    if (mounted) _progressController.forward(from: 0);
  }

  Future<VideoPlayerController> _getVideoController(StoryModel story) async {
    final cached = _videoControllers[story.storyId];
    if (cached != null) return cached;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(story.mediaUrl),
    );
    await controller.initialize();
    _videoControllers[story.storyId] = controller;
    return controller;
  }

  void _markCurrentStoryViewed() {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    if (user.uid == _story.ownerId) return;
    if (!_markedViewedStoryIds.add(_story.storyId)) return;

    StoryService().markStoryViewed(
      storyId: _story.storyId,
      viewerId: user.uid,
    );
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _showCurrentStory();
      return;
    }
    Navigator.pop(context);
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _showCurrentStory();
      return;
    }
    _progressController.forward(from: 0);
  }

  void _pauseStory() {
    _progressController.stop();
    _activeVideoController?.pause();
  }

  void _resumeStory() {
    _progressController.forward();
    _activeVideoController?.play();
  }

  Future<void> _deleteCurrentStory() async {
    _pauseStory();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa story?'),
        content: const Text('Story này sẽ bị xóa khỏi hồ sơ của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) _resumeStory();
      return;
    }

    await StoryService().deleteStory(_story.storyId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showViewers() async {
    _pauseStory();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<UserModel>>(
          future: StoryService().getStoryViewers(_story.viewers),
          builder: (context, snapshot) {
            final viewers = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (viewers.isEmpty) {
              return const SizedBox(
                height: 180,
                child: Center(child: Text('Chưa có người xem')),
              );
            }
            return SafeArea(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final viewer = viewers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: viewer.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(viewer.photoUrl)
                          : null,
                      child: viewer.photoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      viewer.username,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
    if (mounted) _resumeStory();
  }

  Future<void> _sendReply({String? reaction}) async {
    final user = context.read<UserProvider>().user;
    if (user == null || user.uid == _story.ownerId || _isSendingReply) return;

    final text = reaction ?? _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingReply = true);
    try {
      await ChatService().sendMessage(
        senderId: user.uid,
        receiverId: _story.ownerId,
        text: reaction == null
            ? 'Trả lời story của ${_story.username}: $text'
            : '$text story của ${_story.username}',
      );
      _replyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi phản hồi')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final isMyStory = currentUser?.uid == _story.ownerId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 280) Navigator.pop(context);
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevStory();
          } else if (details.globalPosition.dx > width * 2 / 3) {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: _buildStoryMedia()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.50),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBars(),
                  _buildHeader(isMyStory: isMyStory),
                  const Spacer(),
                  _buildTaggedUsers(),
                  _buildBottomActions(isMyStory: isMyStory),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryMedia() {
    if (_story.isVideo) {
      return FutureBuilder<VideoPlayerController>(
        future: _getVideoController(_story),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final controller = snapshot.data!;
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: _story.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 42),
      ),
    );
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: List.generate(
          widget.stories.length,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: index == _currentIndex
                    ? AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) => LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.35),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : LinearProgressIndicator(
                        value: index < _currentIndex ? 1 : 0,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isMyStory}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: _story.userPhotoUrl.isNotEmpty
                ? CachedNetworkImageProvider(_story.userPhotoUrl)
                : null,
            child:
                _story.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _story.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  timeago.format(_story.timestamp.toDate(), locale: 'vi'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isMyStory)
            IconButton(
              onPressed: _deleteCurrentStory,
              icon: const Icon(Icons.more_horiz, color: Colors.white),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTaggedUsers() {
    if (_story.taggedUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _story.taggedUsers.map((user) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '@${user['username'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomActions({required bool isMyStory}) {
    if (isMyStory) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _showViewers,
              icon: const Icon(Icons.visibility, color: Colors.white),
              label: Text(
                '${_story.viewers.length} lượt xem',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            IconButton.filled(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UploadScreen(initialTab: 1),
                  ),
                );
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['❤️', '😂', '🔥', '👏'].map((emoji) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _sendReply(reaction: emoji),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Trả lời story...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onTap: _pauseStory,
                  onSubmitted: (_) => _sendReply(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSendingReply ? null : () => _sendReply(),
                icon: _isSendingReply
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
