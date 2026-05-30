import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

class ShareBottomSheet extends StatefulWidget {
  final PostModel post;
  final String? currentUserId;

  const ShareBottomSheet({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  late Future<List<UserModel>> _usersFuture;
  final Set<String> _selectedUserIds = {};
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _getAllUsers();
  }

  Future<List<UserModel>> _getAllUsers() async {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null) return [];
    return UserService().getShareableUsers(currentUserId);
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

  Future<void> _shareToSelectedUsers() async {
    if (widget.currentUserId == null ||
        _selectedUserIds.isEmpty ||
        _isSharing) {
      return;
    }

    setState(() => _isSharing = true);

    try {
      for (final receiverId in _selectedUserIds) {
        await ChatService().sendSharedPost(
          senderId: widget.currentUserId!,
          receiverId: receiverId,
          postId: widget.post.postId,
        );
      }

      if (!mounted) return;
      final sharedCount = _selectedUserIds.length;
      setState(() => _isSharing = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chia sẻ bài viết cho $sharedCount người')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chia sẻ bài viết: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chia sẻ bài viết',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _isSharing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Đã chọn ${_selectedUserIds.length} người',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<UserModel>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Center(
                    child: Text('Không có người dùng nào để chia sẻ'),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUserIds.contains(user.uid);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged:
                          _isSharing ? null : (_) => _toggleUser(user.uid),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: CircleAvatar(
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.username),
                      subtitle: Text(user.email),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedUserIds.isEmpty || _isSharing
                      ? null
                      : _shareToSelectedUsers,
                  child: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _selectedUserIds.isEmpty
                              ? 'Chọn người nhận'
                              : 'Gửi cho ${_selectedUserIds.length} người',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
