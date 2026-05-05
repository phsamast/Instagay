import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/user_service.dart';
import '../../services/post_service.dart';
import '../profile/profile_screen.dart';
import '../../widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });
    
    final results = await UserService().searchUsers(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm người dùng...',
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
          ),
          onChanged: _search,
        ),
      ),
      body: _isSearching ? _buildSearchResults() : _buildExploreGrid(),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy người dùng',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(
            user.username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${user.followers.length} người theo dõi',
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user.uid),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExploreGrid() {
    return StreamBuilder<List<PostModel>>(
      // Lấy danh sách bài viết toàn cục (explore)
      stream: PostService().getAllPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Center(child: Text('Chưa có nội dung khám phá'));
        }

        return MasonryGridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            // Render ngẫu nhiên tile dọc hoặc hình vuông
            final isTall = index % 5 == 0;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Khám phá')),
                      body: SingleChildScrollView(
                        child: PostCard(post: post),
                      ),
                    ),
                  ),
                );
              },
              child: SizedBox(
                height: isTall ? 250 : 125,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.mediaUrl,
                      fit: BoxFit.cover,
                    ),
                    if (post.isVideo)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(Icons.play_arrow, color: Colors.white),
                      )
                    else if (post.isMultiple)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(Icons.collections, color: Colors.white, size: 20),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}