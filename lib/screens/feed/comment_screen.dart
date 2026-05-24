import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/comment_model.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';

class CommentScreen extends StatefulWidget {
  final PostModel post;
  final String? highlightedCommentId;
  final String? highlightedUserId;

  const CommentScreen({
    super.key,
    required this.post,
    this.highlightedCommentId,
    this.highlightedUserId,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() {
    final canSend = _commentController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final user = context.read<UserProvider>().user;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    await PostService().addComment(
      postId: widget.post.postId,
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
      text: text,
    );

    _commentController.clear();
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Bình luận')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: PostService().getComments(widget.post.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Center(child: Text('Chưa có bình luận nào'));
                }

                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isHighlighted = (widget.highlightedCommentId !=
                                null &&
                            comment.commentId == widget.highlightedCommentId) ||
                        (widget.highlightedCommentId == null &&
                            widget.highlightedUserId != null &&
                            comment.userId == widget.highlightedUserId);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? Colors.blue.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: comment.userPhotoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      comment.userPhotoUrl,
                                    )
                                  : null,
                              child: comment.userPhotoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: Colors.black,
                                        height: 1.25,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${comment.username} ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: comment.text),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(
                                      comment.timestamp.toDate(),
                                      locale: 'vi',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _commentController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Thêm bình luận...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        minLines: 1,
                        maxLines: null,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSending || !_canSend ? null : _sendComment,
                    child: _isSending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Đăng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
