import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post_model.dart';
import '../providers/user_provider.dart';
import '../services/post_service.dart';
import '../screens/feed/comment_screen.dart';
import '../screens/profile/profile_screen.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final isLiked = currentUser != null && post.isLikedBy(currentUser.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========== HEADER: Ảnh đại diện + tên user ==========
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: post.ownerId),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: post.userPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(post.userPhotoUrl)
                      : null,
                  child: post.userPhotoUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: post.ownerId),
                      ),
                    );
                  },
                  child: Text(
                    post.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Nút 3 chấm (xóa bài nếu là chủ)
              if (currentUser?.uid == post.ownerId)
                PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Text('Xóa bài')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      PostService().deletePost(post.postId);
                    }
                  },
                ),
            ],
          ),
        ),

        // ========== ẢNH BÀI ĐĂNG ==========
        GestureDetector(
          onDoubleTap: () {
            // Double tap để like
            if (currentUser != null) {
              PostService().likePost(
                postId: post.postId,
                userId: currentUser.uid,
                isLiked: isLiked,
              );
            }
          },
          child: CachedNetworkImage(
            imageUrl: post.mediaUrl,
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
          ),
        ),

        // ========== ACTION BUTTONS ==========
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Nút Like
              IconButton(
                onPressed: () {
                  if (currentUser != null) {
                    PostService().likePost(
                      postId: post.postId,
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
              // Nút Comment
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentScreen(post: post),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
              ),
              const Spacer(),
            ],
          ),
        ),

        // ========== SỐ LƯỢT LIKE ==========
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${post.likeCount} lượt thích',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // ========== MÔ TẢ ==========
        if (post.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(
                    text: '${post.username} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: post.description),
                ],
              ),
            ),
          ),

        // ========== THỜI GIAN ==========
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            timeago.format(post.timestamp.toDate(), locale: 'vi'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        const Divider(height: 8),
      ],
    );
  }
}