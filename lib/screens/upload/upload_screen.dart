import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';
import '../../services/story_service.dart';
import '../../services/user_service.dart';
import '../home/home_screen.dart';

class UploadScreen extends StatefulWidget {
  final int initialTab;

  const UploadScreen({super.key, this.initialTab = 0});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _captionController = TextEditingController();
  final _tagSearchController = TextEditingController();
  final _picker = ImagePicker();
  final _userService = UserService();

  List<File> _imageFiles = [];
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _isLoading = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  List<UserModel> _taggedUsers = [];
  List<UserModel> _tagSearchResults = [];
  bool _isSearchingTags = false;
  Timer? _tagDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _captionController.dispose();
    _tagSearchController.dispose();
    _tagDebounce?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMultipleImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() {
      _imageFiles = picked.map((item) => File(item.path)).toList();
      _videoFile = null;
      _isVideo = false;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  Future<void> _pickCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _imageFiles = [File(picked.path)];
      _videoFile = null;
      _isVideo = false;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    final file = File(picked.path);
    _videoController?.dispose();
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    setState(() {
      _videoFile = file;
      _imageFiles = [];
      _isVideo = true;
      _videoController = controller;
    });
  }

  Future<void> _uploadPost() async {
    if (_imageFiles.isEmpty && _videoFile == null) {
      _showSnackBar('Vui lòng chọn ảnh hoặc video');
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _startUploading('Đang tải media lên...');
    final result = await PostService().uploadPost(
      mediaFiles: _isVideo ? [_videoFile!] : _imageFiles,
      mediaType: _isVideo ? 'video' : 'image',
      description: _captionController.text.trim(),
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
      taggedUsers: _taggedUsers.map(_taggedUserToMap).toList(),
      onProgress: _setUploadProgress,
    );

    if (!mounted) return;
    if (result == 'success') {
      _setUploadProgress(1);
      _showSnackBar('Đã đăng bài');
      _resetComposer();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      _finishUploading();
      _showSnackBar('Lỗi: $result');
    }
  }

  Future<void> _uploadStory() async {
    if (_imageFiles.isEmpty) {
      _showSnackBar('Vui lòng chọn ảnh cho story');
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _startUploading('Đang đăng story...');
    final result = await StoryService().uploadStory(
      imageFile: _imageFiles.first,
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
      taggedUsers: _taggedUsers.map(_taggedUserToMap).toList(),
      onProgress: _setUploadProgress,
    );

    if (!mounted) return;
    if (result == 'success') {
      _setUploadProgress(1);
      _showSnackBar('Đã đăng story');
      _resetComposer();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      _finishUploading();
      _showSnackBar('Lỗi: $result');
    }
  }

  void _startUploading(String status) {
    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
      _uploadStatus = status;
    });
  }

  void _setUploadProgress(double value) {
    if (!mounted) return;
    setState(() {
      _uploadProgress = value.clamp(0, 1).toDouble();
      if (_uploadProgress >= 1) _uploadStatus = 'Đang hoàn tất...';
    });
  }

  void _finishUploading() {
    setState(() {
      _isLoading = false;
      _uploadStatus = '';
      _uploadProgress = 0;
    });
  }

  void _resetComposer() {
    setState(() {
      _imageFiles = [];
      _videoFile = null;
      _isVideo = false;
      _isLoading = false;
      _uploadProgress = 0;
      _uploadStatus = '';
      _taggedUsers = [];
      _tagSearchResults = [];
      _tagSearchController.clear();
      _videoController?.dispose();
      _videoController = null;
    });
    _captionController.clear();
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
      final users = await _userService.searchUsers(query);
      if (!mounted) return;
      final taggedIds = _taggedUsers.map((user) => user.uid).toSet();
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isStoryTab = _tabController.index == 1;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          isStoryTab ? 'Tạo story' : 'Bài viết mới',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed:
                _isLoading ? null : (isStoryTab ? _uploadStory : _uploadPost),
            child: Text(
              isStoryTab ? 'Đăng' : 'Chia sẻ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _buildSegmentedTabs(),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildComposer(isStory: false),
              _buildComposer(isStory: true),
            ],
          ),
          _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'Bài viết'),
          Tab(text: 'Story'),
        ],
      ),
    );
  }

  Widget _buildComposer({required bool isStory}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isStory ? _buildStoryPreview() : _buildPostPreview(),
          ),
          const SizedBox(height: 16),
          _buildMediaActions(isStory: isStory),
          if (!isStory) ...[
            const SizedBox(height: 18),
            _buildCaptionField(),
          ],
          const SizedBox(height: 18),
          _buildTagPeopleSection(),
          const SizedBox(height: 18),
          _buildUploadButton(isStory: isStory),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    if (_isVideo &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return _previewFrame(
        key: const ValueKey('video'),
        aspectRatio:
            _videoController!.value.aspectRatio.clamp(0.75, 1.35).toDouble(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            IconButton.filled(
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              icon: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 34,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _mediaBadge(
                  _formatDuration(_videoController!.value.duration)),
            ),
          ],
        ),
      );
    }

    if (_imageFiles.isNotEmpty) {
      return _previewFrame(
        key: ValueKey('images-${_imageFiles.length}'),
        child: _imageFiles.length == 1
            ? Image.file(_imageFiles.first, fit: BoxFit.cover)
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: _imageFiles.length,
                    itemBuilder: (_, index) => Image.file(
                      _imageFiles[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _mediaBadge('${_imageFiles.length} ảnh'),
                  ),
                ],
              ),
      );
    }

    return _emptyPicker(
      key: const ValueKey('empty-post'),
      title: 'Chọn ảnh hoặc video',
      icon: Icons.add_photo_alternate_outlined,
      onTap: _showImageOptions,
    );
  }

  Widget _buildStoryPreview() {
    if (_imageFiles.isNotEmpty) {
      return _previewFrame(
        key: const ValueKey('story-image'),
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_imageFiles.first, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black38, Colors.transparent, Colors.black26],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _taggedUsers
                    .map((user) => _storyTagPill('@${user.username}'))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return _emptyPicker(
      key: const ValueKey('empty-story'),
      title: 'Chọn ảnh cho story',
      icon: Icons.auto_awesome,
      aspectRatio: 9 / 16,
      onTap: _showImageOptions,
    );
  }

  Widget _previewFrame({
    required Widget child,
    Key? key,
    double aspectRatio = 1,
  }) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(color: Colors.black, child: child),
      ),
    );
  }

  Widget _emptyPicker({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Key? key,
    double aspectRatio = 1,
  }) {
    return GestureDetector(
      key: key,
      onTap: _isLoading ? null : onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 54, color: Colors.black87),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Thư viện hoặc camera',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaActions({required bool isStory}) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.photo_library_outlined,
            label: isStory ? 'Chọn ảnh' : 'Ảnh',
            onPressed: _isLoading ? null : _showImageOptions,
          ),
        ),
        if (!isStory) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              icon: Icons.videocam_outlined,
              label: 'Video',
              onPressed: _isLoading ? null : _showVideoOptions,
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Camera',
            onPressed: _isLoading ? null : _pickCamera,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      controller: _captionController,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
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
                        onDeleted: _isLoading
                            ? null
                            : () => _removeTaggedUser(user.uid),
                      );
                    }).toList(),
                  ),
                ),
        ),
        TextField(
          controller: _tagSearchController,
          enabled: !_isLoading,
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

  Widget _buildUploadButton({required bool isStory}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isLoading ? null : (isStory ? _uploadStory : _uploadPost),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          isStory ? 'Đăng story' : 'Chia sẻ bài viết',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return IgnorePointer(
      ignoring: !_isLoading,
      child: AnimatedOpacity(
        opacity: _isLoading ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _uploadStatus,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${(_uploadProgress * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _uploadProgress == 0 ? null : _uploadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _storyTagPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Chọn video từ thư viện'),
              subtitle: const Text('Tối đa 3 phút'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Quay video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
