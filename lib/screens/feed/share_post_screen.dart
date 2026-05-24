import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';

class SharePostScreen extends StatefulWidget {
  final PostModel post;

  const SharePostScreen({super.key, required this.post});

  @override
  State<SharePostScreen> createState() => _SharePostScreenState();
}

class _SharePostScreenState extends State<SharePostScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) return;

    final uids = <String>{
      ...currentUser.followers.map((id) => id.toString()),
      ...currentUser.following.map((id) => id.toString()),
    }.where((id) => id != currentUser.uid).toList();

    final users = await UserService().getUsersByUids(uids);
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _filteredUsers = users;
      _isLoading = false;
    });
  }

  void _filterUsers(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _filteredUsers = normalized.isEmpty
          ? _allUsers
          : _allUsers
              .where((user) =>
                  user.username.toLowerCase().contains(normalized) ||
                  user.email.toLowerCase().contains(normalized))
              .toList();
    });
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _sharePost() async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null || _selectedUserIds.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final message = _buildShareMessage(currentUser.username);

    for (final receiverId in _selectedUserIds) {
      await ChatService().sendMessage(
        senderId: currentUser.uid,
        receiverId: receiverId,
        text: message,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Đã chia sẻ cho ${_selectedUserIds.length} người')),
    );
  }

  String _buildShareMessage(String senderUsername) {
    final buffer = StringBuffer()
      ..writeln('$senderUsername đã chia sẻ một bài viết')
      ..writeln('Tác giả: ${widget.post.username}');
    if (widget.post.description.trim().isNotEmpty) {
      buffer.writeln('Nội dung: ${widget.post.description.trim()}');
    }
    if (widget.post.mediaUrl.isNotEmpty) {
      buffer.writeln(widget.post.mediaUrl);
    }
    buffer.write('post:${widget.post.postId}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ bài viết'),
        actions: [
          TextButton(
            onPressed:
                _selectedUserIds.isEmpty || _isSending ? null : _sharePost,
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Gửi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPostPreview(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người nhận...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Đã chọn ${_selectedUserIds.length} người',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _allUsers.isEmpty
                              ? 'Bạn chưa có người theo dõi hoặc đang theo dõi ai'
                              : 'Không tìm thấy người dùng nào',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected =
                              _selectedUserIds.contains(user.uid);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleUser(user.uid),
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: CircleAvatar(
                              radius: 24,
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 24)
                                  : null,
                            ),
                            title: Text(
                              user.username,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: user.bio.isEmpty
                                ? null
                                : Text(
                                    user.bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 58,
              child: widget.post.mediaUrl.isEmpty
                  ? Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported_outlined),
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.post.mediaUrl,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.post.description.isEmpty
                      ? 'Bài viết ${widget.post.isVideo ? 'video' : 'ảnh'}'
                      : widget.post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
