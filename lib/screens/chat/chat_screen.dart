import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/post_service.dart';
import 'chat_information.dart';
import 'fullscreen_video_player.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, VideoPlayerController> _videoControllers = {};

  bool _isSending = false;
  bool _canSend = false;

  Stream<List<MessageModel>>? _messagesStream;
  String? _messagesStreamUserId;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    final canSend = _messageController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();

    for (var controller in _videoControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Stream<List<MessageModel>>? _getMessagesStream(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return null;

    if (_messagesStream == null || _messagesStreamUserId != currentUserId) {
      _messagesStreamUserId = currentUserId;
      _messagesStream = ChatService().getMessages(
        currentUserId,
        widget.otherUser.uid,
      );
      _lastMessageCount = 0;
    }

    return _messagesStream;
  }

  Future<void> _sendMessage() async {
    final user = context.read<UserProvider>().user;
    final text = _messageController.text.trim();

    if (user == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ChatService().sendMessage(
        senderId: user.uid,
        receiverId: widget.otherUser.uid,
        text: text,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        await _sendMedia(image.path, 'image');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        await _sendMedia(video.path, 'video');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _sendMedia(String filePath, String type) async {
    final user = context.read<UserProvider>().user;
    if (user == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      await ChatService().sendMedia(
        senderId: user.uid,
        receiverId: widget.otherUser.uid,
        filePath: filePath,
        mediaType: type,
      );

      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi media: $e')),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Chọn ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blue),
              title: const Text('Chọn video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Chụp ảnh'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final XFile? image = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );

                  if (image != null) {
                    await _sendMedia(image.path, 'image');
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final messagesStream = _getMessagesStream(currentUser?.uid);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: _openChatInformation,
          child: Row(
            children: [
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.otherUser.photoUrl.isNotEmpty
                    ? NetworkImage(widget.otherUser.photoUrl)
                    : null,
                child: widget.otherUser.photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherUser.username,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 200,
        actions: [
          IconButton(
            onPressed: _openChatInformation,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<MessageModel>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Bắt đầu trò chuyện với ${widget.otherUser.username}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 14,
                              backgroundImage:
                              widget.otherUser.photoUrl.isNotEmpty
                                  ? NetworkImage(
                                widget.otherUser.photoUrl,
                              )
                                  : null,
                              child: widget.otherUser.photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (message.mediaUrl != null &&
                                  message.mediaUrl!.isNotEmpty)
                                _buildMediaMessage(message, isMe)
                              else if (message.sharedPostId != null &&
                                  message.sharedPostId!.isNotEmpty)
                                _buildSharedPostMessage(message, isMe)
                              else
                                _buildTextMessage(message, isMe),
                              const SizedBox(height: 2),
                              Text(
                                timeago.format(
                                  message.timestamp.toDate(),
                                  locale: 'vi',
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
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
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _isSending ? null : _showMediaOptions,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _isSending ? Colors.grey : Colors.blue,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _messageController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Nhắn tin...',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending || !_canSend ? null : _sendMessage,
                    icon: Icon(
                      Icons.send,
                      color:
                      _isSending || !_canSend ? Colors.grey : Colors.blue,
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

  void _openChatInformation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatInformation(
          chatId: widget.otherUser.uid,
          chatName: widget.otherUser.username,
          chatImage: widget.otherUser.photoUrl,
          isGroup: false,
          members: [
            {
              'name': widget.otherUser.username,
              'avatar': widget.otherUser.photoUrl,
              'uid': widget.otherUser.uid,
            }
          ],
          otherUser: widget.otherUser,
        ),
      ),
    );
  }

  Widget _buildTextMessage(MessageModel message, bool isMe) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildMediaMessage(MessageModel message, bool isMe) {
    final isImage = message.mediaType == 'image';

    if (isImage) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 250,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildVideoPlayer(message.mediaUrl!),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: FutureBuilder<VideoPlayerController>(
        future: _getOrCreateVideoController(videoUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            );
          }

          final controller = snapshot.data!;

          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<VideoPlayerController> _getOrCreateVideoController(
      String videoUrl,
      ) async {
    if (_videoControllers.containsKey(videoUrl)) {
      return _videoControllers[videoUrl]!;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    _videoControllers[videoUrl] = controller;

    return controller;
  }

  Widget _buildSharedPostMessage(MessageModel message, bool isMe) {
    return FutureBuilder<PostModel?>(
      future: PostService().getPostById(message.sharedPostId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.65,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.65,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Bài viết không tồn tại'),
          );
        }

        final post = snapshot.data!;

        return Container(
          width: MediaQuery.of(context).size.width * 0.65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: post.userPhotoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(post.userPhotoUrl)
                          : null,
                      child: post.userPhotoUrl.isEmpty
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.mediaUrls.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: post.mediaUrls.first,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.grey[300],
                  ),
                ),
              if (post.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}