import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _captionController = TextEditingController();
  final _tagSearchController = TextEditingController();
  final _userService = UserService();

  List<UserModel> _taggedUsers = [];
  List<UserModel> _tagSearchResults = [];
  bool _isSaving = false;
  bool _isSearchingTags = false;
  Timer? _tagDebounce;

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.post.description;
    _taggedUsers = widget.post.taggedUsers.map(_userFromTag).toList();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tagSearchController.dispose();
    _tagDebounce?.cancel();
    super.dispose();
  }

  Future<void> _savePost() async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null || _isSaving) return;

    setState(() => _isSaving = true);

    final result = await PostService().updatePost(
      postId: widget.post.postId,
      currentUserId: currentUser.uid,
      description: _captionController.text.trim(),
      taggedUsers: _taggedUsers.map(_taggedUserToMap).toList(),
      fromUsername: currentUser.username,
      fromUserPhotoUrl: currentUser.photoUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result == 'success') {
      final updatedPost = widget.post.copyWith(
        description: _captionController.text.trim(),
        taggedUsers: _taggedUsers.map(_taggedUserToMap).toList(),
      );
      Navigator.pop(context, updatedPost);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể lưu thay đổi: $result')),
    );
  }

  UserModel _userFromTag(Map<String, dynamic> tag) {
    return UserModel(
      uid: tag['uid']?.toString() ?? '',
      username: tag['username']?.toString() ?? '',
      email: tag['email']?.toString() ?? '',
      photoUrl: tag['photoUrl']?.toString() ?? '',
      bio: '',
      followers: const [],
      following: const [],
      savedPosts: const [],
    );
  }

  Map<String, dynamic> _taggedUserToMap(UserModel user) {
    return {
      'uid': user.uid,
      'username': user.username,
      'photoUrl': user.photoUrl,
    };
  }

  void _onTagSearchChanged(String value) {
    _tagDebounce?.cancel();
    _tagDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) setState(() => _tagSearchResults = []);
        return;
      }

      setState(() => _isSearchingTags = true);
      final currentUserId = context.read<UserProvider>().user?.uid;
      final taggedIds = _taggedUsers.map((user) => user.uid).toSet();
      final users = await _userService.searchUsers(query);

      if (!mounted) return;
      setState(() {
        _tagSearchResults = users
            .where((user) =>
                user.uid != currentUserId && !taggedIds.contains(user.uid))
            .toList();
        _isSearchingTags = false;
      });
    });
  }

  void _addTaggedUser(UserModel user) {
    if (_taggedUsers.any((item) => item.uid == user.uid)) return;
    setState(() {
      _taggedUsers = [..._taggedUsers, user];
      _tagSearchResults = [];
      _tagSearchController.clear();
    });
  }

  void _removeTaggedUser(String userId) {
    setState(() {
      _taggedUsers = _taggedUsers.where((user) => user.uid != userId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.select<UserProvider, String?>(
      (provider) => provider.user?.uid,
    );
    final canEdit = currentUserId == widget.post.ownerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sửa bài viết',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: !_isSaving && canEdit ? _savePost : null,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
      body: !canEdit
          ? const Center(child: Text('Bạn không có quyền sửa bài viết này'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _buildMediaPreview(),
                const SizedBox(height: 18),
                _buildCaptionField(),
                const SizedBox(height: 18),
                _buildTagPeopleSection(),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isSaving ? null : _savePost,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMediaPreview() {
    if (widget.post.mediaUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.post.isVideo) {
      return _previewFrame(
        child: Stack(
          alignment: Alignment.center,
          children: [
            const ColoredBox(color: Colors.black),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
            Positioned(
              right: 12,
              bottom: 12,
              child: _mediaBadge('Video'),
            ),
          ],
        ),
      );
    }

    return _previewFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.post.mediaUrls.first,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => ColoredBox(
              color: Colors.grey.shade200,
              child: const Icon(Icons.error_outline),
            ),
          ),
          if (widget.post.isMultiple)
            Positioned(
              right: 12,
              top: 12,
              child: _mediaBadge('${widget.post.mediaUrls.length} ảnh'),
            ),
        ],
      ),
    );
  }

  Widget _previewFrame({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: child,
      ),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      controller: _captionController,
      enabled: !_isSaving,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: 'Chú thích',
        hintText: 'Viết chú thích...',
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildTagPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.alternate_email, size: 20),
            SizedBox(width: 8),
            Text(
              'Tag người khác',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _taggedUsers.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taggedUsers.map((user) {
                      return InputChip(
                        avatar: CircleAvatar(
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        label: Text('@${user.username}'),
                        onDeleted: _isSaving
                            ? null
                            : () => _removeTaggedUser(user.uid),
                      );
                    }).toList(),
                  ),
                ),
        ),
        TextField(
          controller: _tagSearchController,
          enabled: !_isSaving,
          onChanged: _onTagSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm username để tag',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearchingTags
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tagSearchResults.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(_tagSearchResults.length),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _tagSearchResults.map((user) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          user.username,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(user.email),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => _addTaggedUser(user),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _mediaBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
