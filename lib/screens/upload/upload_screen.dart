import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
  File? _imageFile;
  final _captionController = TextEditingController();
  bool _isLoading = false;
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
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _uploadPost() async {
    if (_imageFile == null) {
      _showSnackBar('Vui lòng chọn ảnh');
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);

    final result = await PostService().uploadPost(
      imageFile: _imageFile!,
      description: _captionController.text.trim(),
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result == 'success') {
        // Reset form
        setState(() => _imageFile = null);
        _captionController.clear();
        _showSnackBar('Đăng bài thành công!');
      } else {
        _showSnackBar('Lỗi: $result');
      }
    }
  }


  Future<void> _uploadStory() async {
    if (_imageFile == null) {
      _showSnackBar('Vui lòng chọn ảnh');
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);

    final result = await StoryService().uploadStory(
      imageFile: _imageFile!,
      userId: user.uid,
      username: user.username,
      userPhotoUrl: user.photoUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result == 'success') {
        setState(() => _imageFile = null);
        _showSnackBar('Story đã được đăng!');
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

          _buildImagePicker(),
          const SizedBox(height: 16),

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
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Đăng bài'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildImagePicker(),
          const SizedBox(height: 16),
          const Text(
            'Story sẽ tự động biến mất sau 24 giờ',
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

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showPickerOptions(),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _imageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_imageFile!, fit: BoxFit.cover),
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
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}