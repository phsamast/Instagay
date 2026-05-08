import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  final AuthService _authService = AuthService();
  StreamSubscription<UserModel>? _userSubscription;

  UserModel? get user => _user;

  Future<void> loadUser() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _userSubscription?.cancel();
      _userSubscription = UserService().streamUser(currentUser.uid).listen((updatedUser) {
        _user = updatedUser;
        notifyListeners();
      });
    }
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }
  void clearUser() {
    _user = null;
    _userSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}