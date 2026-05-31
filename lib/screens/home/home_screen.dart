import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../chat/chat_list_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isBottomNavVisible = true;
  double _scrollDistance = 0;

  static const double _hideShowThreshold = 36;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUser();
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_currentIndex != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification.metrics.pixels <= 0) {
      _setBottomNavVisible(true);
      _scrollDistance = 0;
      return false;
    }

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _scrollDistance = 0;
      return false;
    }

    if (notification is! ScrollUpdateNotification ||
        notification.scrollDelta == null) {
      return false;
    }

    final delta = notification.scrollDelta!;
    if (delta.abs() < 1) return false;

    final shouldHide = delta > 0;
    if ((_isBottomNavVisible && shouldHide) ||
        (!_isBottomNavVisible && !shouldHide)) {
      _scrollDistance += delta.abs();
    } else {
      _scrollDistance = delta.abs();
    }

    if (_scrollDistance >= _hideShowThreshold) {
      _setBottomNavVisible(!shouldHide);
      _scrollDistance = 0;
    }

    return false;
  }

  void _setBottomNavVisible(bool visible) {
    if (_isBottomNavVisible == visible) return;
    setState(() => _isBottomNavVisible = visible);
  }

  Widget _buildProfileIcon(dynamic user, bool isActive) {
    final photoUrl = user?.photoUrl ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.black : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: CircleAvatar(
            radius: 11,
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(dynamic user) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: _isBottomNavVisible ? 1 : 0,
        end: _isBottomNavVisible ? 1 : 0,
      ),
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 16),
                child: child,
              ),
            ),
          ),
        );
      },
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index != 0) _isBottomNavVisible = true;
            _scrollDistance = 0;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.send_outlined),
            activeIcon: Icon(Icons.send),
            label: 'Direct',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Tìm kiếm',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(user, false),
            activeIcon: _buildProfileIcon(user, true),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final userId = user?.uid;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: userProvider.errorMessage == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 52,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: userProvider.loadUser,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final screens = [
      const FeedScreen(),
      const ChatListScreen(),
      const SearchScreen(),
      ProfileScreen(userId: userId ?? ''),
    ];

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(user),
    );
  }
}
