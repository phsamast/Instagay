import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  final AuthService _authService = AuthService();

  UserModel? get user => _user;

  Future<void> loadUser() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _user = await _authService.getUserData(currentUser.uid);
      notifyListeners();
    }
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }
  void clearUser() {
    _user = null;
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
}