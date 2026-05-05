import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';
import '../../services/story_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<File> _imageFiles = []; // Hỗ trợ nhiều ảnh
  File? _videoFile;
  VideoPlayerController? _videoController;
  final _captionController = TextEditingController();
  bool _isLoading = false;
  bool _isVideo = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMultipleImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isNotEmpty) {
      setState(() {
        _imageFiles = picked.map((e) => File(e.path)).toList();
        _videoFile = null;
        _isVideo = false;
        _videoController?.dispose();
        _videoController = null;
      });
    }
  }

  // Chụp ảnh bằng camera
  Future<void> _pickCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _imageFiles = [File(picked.path)];
        _videoFile = null;
        _isVideo = false;
      });
    }
  }

  // Chọn video
  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3), // Giới hạn 3 phút
    );
    if (picked != null) {
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
  }

  Future<void> _uploadPost() async {
    if (_imageFiles.isEmpty && _videoFile == null) {
      _showSnackBar('Vui lòng chọn ảnh hoặc video');
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);

    final result = await PostService().uploadPost(
      mediaFiles: _isVideo ? [_videoFile!] : _imageFiles,
      mediaType: _isVideo ? 'video' : 'image',
      description: _captionController.text.trim(),
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result == 'success') {
        setState(() {
          _imageFiles = [];
          _videoFile = null;
          _videoController?.dispose();
          _videoController = null;
          _isVideo = false;
        });
        _captionController.clear();
        _showSnackBar('Đăng bài thành công! 🎉');
      } else {
        _showSnackBar('Lỗi: $result');
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_imageFiles.isEmpty) {
      _showSnackBar('Vui lòng chọn ảnh cho story');
      return;
    }
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);
    final result = await StoryService().uploadStory(
      imageFile: _imageFiles.first,
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result == 'success') {
        setState(() => _imageFiles = []);
        _showSnackBar('Story đã được đăng! ✨');
      } else {
        _showSnackBar('Lỗi: $result');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng tải'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bài đăng'),
            Tab(text: 'Story'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostTab(),
          _buildStoryTab(),
        ],
      ),
    );
  }

  Widget _buildPostTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Nút chọn loại media
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showImageOptions,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn ảnh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isVideo ? Colors.grey : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showVideoOptions,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Chọn video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isVideo ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Preview
          _buildPreview(),

          const SizedBox(height: 16),

          // Caption
          TextField(
            controller: _captionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Viết chú thích...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _uploadPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Đang tải lên...'),
                ],
              )
                  : const Text('Đăng bài'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // Preview video
    if (_isVideo && _videoController != null && _videoController!.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // Nút play/pause
          GestureDetector(
            onTap: () {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          // Thời lượng video
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(_videoController!.value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    // Preview nhiều ảnh
    if (_imageFiles.isNotEmpty) {
      if (_imageFiles.length == 1) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _imageFiles.first,
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }

      // Grid nhiều ảnh
      return Column(
        children: [
          Text(
            '${_imageFiles.length} ảnh được chọn',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _imageFiles.length,
            itemBuilder: (_, index) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(_imageFiles[index], fit: BoxFit.cover),
            ),
          ),
        ],
      );
    }

    // Placeholder
    return GestureDetector(
      onTap: _showImageOptions,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('Chạm để chọn ảnh hoặc video',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageOptions,
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _imageFiles.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFiles.first, fit: BoxFit.cover),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('Chạm để chọn ảnh',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Story tự biến mất sau 24 giờ',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _uploadStory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Đăng Story'),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn nhiều ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
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
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Chọn video từ thư viện'),
              subtitle: const Text('Tối đa 3 phút'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
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