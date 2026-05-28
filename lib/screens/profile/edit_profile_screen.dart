import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../services/storage_service.dart'; // ← Dùng Cloudinary

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bioController = TextEditingController();
  File? _newAvatar;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _bioController.text = user?.bio ?? '';
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _saveProfile() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);

    String? photoUrl;
    if (_newAvatar != null) {
      // ← Upload qua Cloudinary thay vì Firebase Storage
      photoUrl = await StorageService.uploadImage(_newAvatar!);
      if (photoUrl == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi upload ảnh, thử lại!')),
          );
        }
        return;
      }
    }

    await UserService().updateProfile(
      userId: user.uid,
      bio: _bioController.text.trim(),
      photoUrl: photoUrl,
    );

    if (!mounted) return;
    await context.read<UserProvider>().loadUser();

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa trang cá nhân'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Đổi ảnh đại diện
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _newAvatar != null
                        ? FileImage(_newAvatar!)
                        : (user?.photoUrl.isNotEmpty == true
                            ? NetworkImage(user!.photoUrl) as ImageProvider
                            : null),
                    child: user?.photoUrl.isEmpty == true && _newAvatar == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              'Đổi ảnh đại diện',
              style: TextStyle(color: Colors.blue),
            ),

            const SizedBox(height: 24),

            // Bio
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: 'Giới thiệu bản thân',
                hintText: 'Viết gì đó về bạn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
