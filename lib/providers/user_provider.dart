import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();
  StreamSubscription<UserModel>? _userSubscription;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadUser() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      clearUser();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _userSubscription?.cancel();
    _userSubscription = UserService().streamUser(currentUser.uid).listen(
      (updatedUser) {
        _user = updatedUser;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _user = null;
        _isLoading = false;
        _errorMessage = _friendlyUserLoadError(error);
        notifyListeners();
      },
    );
  }

  String _friendlyUserLoadError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'Không có quyền đọc dữ liệu người dùng. Hãy kiểm tra Firebase Rules hoặc đăng nhập lại.';
    }
    if (message.contains('unavailable') || message.contains('network')) {
      return 'Không thể kết nối Firebase. Hãy kiểm tra mạng rồi thử lại.';
    }
    if (message.contains('not-found') || message.contains('does not exist')) {
      return 'Không tìm thấy hồ sơ người dùng trong Firestore.';
    }
    return 'Không tải được dữ liệu người dùng: $message';
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _isLoading = false;
    _errorMessage = null;
    _userSubscription?.cancel();
    notifyListeners();
  }

  void followUserLocal(String targetUserId) {
    if (_user != null && !_user!.following.contains(targetUserId)) {
      _user!.following.add(targetUserId);
      notifyListeners();
    }
  }

  void unfollowUserLocal(String targetUserId) {
    if (_user != null && _user!.following.contains(targetUserId)) {
      _user!.following.remove(targetUserId);
      notifyListeners();
    }
  }

  void savePostLocal(String postId) {
    if (_user != null && !_user!.savedPosts.contains(postId)) {
      _user!.savedPosts.add(postId);
      notifyListeners();
    }
  }

  void unsavePostLocal(String postId) {
    if (_user != null && _user!.savedPosts.contains(postId)) {
      _user!.savedPosts.remove(postId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
