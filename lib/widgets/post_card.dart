import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/post_model.dart';
import '../providers/user_provider.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../screens/feed/comment_screen.dart';
import '../screens/profile/profile_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentImageIndex = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _showHeart = false;
  
  bool? _isLiked;
  int? _likeCount;

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.postId != widget.post.postId || oldWidget.post != widget.post) {
      _isLiked = null;
      _likeCount = null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.post.isVideo && widget.post.mediaUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false, // Sẽ tự động play nhờ VisibilityDetector
      looping: true,
      showControls: false, // Ẩn control để giống Instagram
      aspectRatio: _videoController!.value.aspectRatio,
      placeholder: Container(color: Colors.black),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _handleDoubleTapLike(String? currentUserId, bool isLiked) {
    if (currentUserId == null) return;
    setState(() => _showHeart = true);
    
    final currentIsLiked = _isLiked ?? widget.post.isLikedBy(currentUserId);
    final currentLikeCount = _likeCount ?? widget.post.likeCount;

    // Nếu chưa like thì mới like, nếu đã like rồi thì double tap không unlike (theo chuẩn Instagram)
    if (!currentIsLiked) {
      setState(() {
        _isLiked = true;
        _likeCount = currentLikeCount + 1;
      });
      PostService().likePost(
        postId: widget.post.postId,
        userId: currentUserId,
        isLiked: false,
      );
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final isLiked = _isLiked ?? (currentUser != null && widget.post.isLikedBy(currentUser.uid));
    final likeCount = _likeCount ?? widget.post.likeCount;
    final isSaved = currentUser != null && currentUser.savedPosts.contains(widget.post.postId);

    return VisibilityDetector(
      key: Key(widget.post.postId),
      onVisibilityChanged: (info) {
        if (!widget.post.isVideo || _videoController == null) return;
        if (info.visibleFraction > 0.6) {
          _videoController!.play();
        } else {
          _videoController!.pause();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== HEADER ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: widget.post.ownerId),
                  )),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(widget.post.userPhotoUrl)
                        : null,
                    child: widget.post.userPhotoUrl.isEmpty
                        ? const Icon(Icons.person) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: widget.post.ownerId),
                    )),
                    child: Text(
                      widget.post.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (currentUser?.uid == widget.post.ownerId)
                  PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('Xóa bài')),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') PostService().deletePost(widget.post.postId);
                    },
                  ),
              ],
            ),
          ),

          // ========== MEDIA (ảnh hoặc video) ==========
          GestureDetector(
            onDoubleTap: () => _handleDoubleTapLike(currentUser?.uid, isLiked),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.post.isVideo)
                  _buildVideoPlayer()
                else
                  _buildImageCarousel(currentUser),

                // Hiệu ứng thả tim
                if (_showHeart)
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0.5, end: 1.2),
                    builder: (context, val, child) => Transform.scale(
                      scale: val,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 100,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ========== ACTION BUTTONS ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (currentUser != null) {
                      setState(() {
                        _isLiked = !isLiked;
                        _likeCount = isLiked ? likeCount - 1 : likeCount + 1;
                      });
                      PostService().likePost(
                        postId: widget.post.postId,
                        userId: currentUser.uid,
                        isLiked: isLiked,
                      );
                    }
                  },
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CommentScreen(post: widget.post),
                  )),
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                IconButton(
                  onPressed: () {}, // Nút Share (tùy chọn)
                  icon: const Icon(Icons.send_outlined),
                ),
                const Spacer(),
                
                // Chỉ số ảnh (nếu nhiều ảnh)
                if (widget.post.isMultiple && !widget.post.isVideo)
                  Text(
                    '${_currentImageIndex + 1}/${widget.post.mediaUrls.length}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  
                const Spacer(),
                
                // Nút Save/Bookmark
                IconButton(
                  onPressed: () {
                    if (currentUser != null) {
                      if (isSaved) {
                        UserService().unsavePost(currentUser.uid, widget.post.postId);
                      } else {
                        UserService().savePost(currentUser.uid, widget.post.postId);
                      }
                      // Cập nhật lại UI user provider locally
                      context.read<UserProvider>().loadUser();
                    }
                  },
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // ========== LƯỢT LIKE ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$likeCount lượt thích',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // ========== MÔ TẢ ==========
          if (widget.post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: '${widget.post.username} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post.description),
                  ],
                ),
              ),
            ),

          // ========== THỜI GIAN ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              timeago.format(widget.post.timestamp.toDate(), locale: 'vi'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          const Divider(height: 8),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_chewieController != null && _videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    }
    return Container(
      height: 300,
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildImageCarousel(currentUser) {
    if (widget.post.mediaUrls.isEmpty) return const SizedBox.shrink();

    if (widget.post.mediaUrls.length == 1) {
      return CachedNetworkImage(
        imageUrl: widget.post.mediaUrls.first,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 300,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 300,
          color: Colors.grey[200],
          child: const Icon(Icons.error),
        ),
      );
    }

    // Nhiều ảnh → PageView (swipe)
    return Stack(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: widget.post.mediaUrls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (_, index) => CachedNetworkImage(
              imageUrl: widget.post.mediaUrls[index],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
        // Dots indicator
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.post.mediaUrls.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == index ? 8 : 6,
                height: _currentImageIndex == index ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}