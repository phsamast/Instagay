import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../widgets/post_card.dart';
import '../profile/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _historyKey = 'search_history';

  final _searchController = TextEditingController();
  final _postService = PostService();
  final _userService = UserService();

  List<UserModel> _userResults = [];
  List<PostModel> _postResults = [];
  List<UserModel> _suggestedUsers = [];
  List<String> _history = [];

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingSuggestions = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggestions());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _saveHistory(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    final nextHistory = [
      normalizedQuery,
      ..._history.where(
        (item) => item.toLowerCase() != normalizedQuery.toLowerCase(),
      ),
    ].take(10).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, nextHistory);
    if (mounted) setState(() => _history = nextHistory);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() => _history = []);
  }

  Future<void> _loadSuggestions() async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
      return;
    }

    final users = await _userService.getSuggestedUsers(
      currentUserId: currentUser.uid,
      following: currentUser.following,
    );
    if (!mounted) return;

    setState(() {
      _suggestedUsers = users;
      _isLoadingSuggestions = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _isSearching = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    final results = await Future.wait([
      _userService.searchUsers(normalizedQuery.toLowerCase()),
      _postService.searchPosts(normalizedQuery),
    ]);

    if (!mounted) return;
    setState(() {
      _userResults = results[0] as List<UserModel>;
      _postResults = results[1] as List<PostModel>;
      _isLoading = false;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _search('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitSearch(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;
    await _saveHistory(normalizedQuery);
    await _search(normalizedQuery);
  }

  Future<void> _openUser(UserModel user) async {
    await _saveHistory(user.username);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid)),
    );
  }

  Future<void> _openPost(PostModel post, {String title = 'Khám phá'}) async {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) await _saveHistory(query);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _buildSearchField(),
          bottom: _isSearching
              ? const TabBar(
                  indicatorColor: Colors.black,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Người dùng'),
                    Tab(text: 'Bài viết'),
                  ],
                )
              : null,
        ),
        body: _isSearching
            ? TabBarView(
                children: [
                  _buildUserResults(),
                  _buildPostResults(),
                ],
              )
            : _buildDiscoverView(),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: false,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      onSubmitted: _submitSearch,
      decoration: InputDecoration(
        hintText: 'Tìm người dùng hoặc bài viết...',
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
                onPressed: _clearSearch,
              )
            : null,
      ),
    );
  }

  Widget _buildDiscoverView() {
    return CustomScrollView(
      slivers: [
        if (_history.isNotEmpty)
          SliverToBoxAdapter(child: _buildHistorySection()),
        SliverToBoxAdapter(child: _buildSuggestionsSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(
              'Khám phá',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildExploreGrid()),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tìm kiếm gần đây',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: const Text('Xóa'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _history.map((item) {
              return ActionChip(
                avatar: const Icon(Icons.history, size: 18),
                label: Text(item),
                onPressed: () {
                  _searchController.text = item;
                  _submitSearch(item);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    if (_isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Gợi ý người dùng',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _suggestedUsers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final user = _suggestedUsers[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openUser(user),
                child: SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 31,
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${user.followers.length} follower',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserResults() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_userResults.isEmpty) return _emptyState('Không tìm thấy người dùng');

    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
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
          subtitle: Text('${user.followers.length} người theo dõi'),
          onTap: () => _openUser(user),
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_postResults.isEmpty) return _emptyState('Không tìm thấy bài viết');

    return ListView.separated(
      itemCount: _postResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _postThumbnail(post, size: 58),
          title: Text(
            post.description.isEmpty
                ? '(Không có chú thích)'
                : post.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '@${post.username}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _openPost(post, title: 'Bài viết'),
        );
      },
    );
  }

  Widget _buildExploreGrid() {
    return StreamBuilder<List<PostModel>>(
      stream: _postService.getAllPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Center(child: Text('Chưa có nội dung khám phá'));
        }

        return MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isTall = index % 5 == 0;
            return GestureDetector(
              onTap: () => _openPost(post),
              child: SizedBox(
                height: isTall ? 250 : 125,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _postThumbnail(post),
                    if (post.isMultiple)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.collections,
                          color: Colors.white,
                          size: 20,
                        ),
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

  Widget _postThumbnail(PostModel post, {double? size}) {
    final child = post.isVideo
        ? Container(
            color: Colors.black87,
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white54, size: 36),
            ),
          )
        : CachedNetworkImage(
            imageUrl: post.mediaUrl,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
          );

    if (size == null) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
