import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';
import 'select_user_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<UserModel?> _getOtherUser(String chatId, String currentUserId) async {
    final parts = chatId.split('_');
    String otherUserId;

    if (parts[0] == currentUserId) {
      otherUserId = parts[1];
    } else {
      otherUserId = parts[0];
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();

    if (doc.exists) {
      return UserModel.fromDoc(doc);
    }

    return null;
  }

  Future<List<UserModel>> _getSuggestedUsers(String currentUserId) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').limit(10).get();

      return snapshot.docs
          .map((doc) => UserModel.fromDoc(doc))
          .where((user) => user.uid != currentUserId)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelectUserScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline, size: 28),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<ChatModel>>(
              stream: ChatService().getChats(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Đã có lỗi xảy ra:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return _buildEmptyState(currentUser);
                }

                return ListView.builder(
                  itemCount: chats.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSuggestedUsersSection(currentUser);
                    }

                    final chat = chats[index - 1];

                    return FutureBuilder<UserModel?>(
                      future: _getOtherUser(
                        chat.chatId,
                        currentUser.uid,
                      ),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text('...'),
                          );
                        }

                        final otherUser = userSnap.data!;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: otherUser.photoUrl.isNotEmpty
                                ? NetworkImage(otherUser.photoUrl)
                                : null,
                            child: otherUser.photoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            otherUser.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Text(
                            timeago.format(
                              chat.lastMessageTime.toDate(),
                              locale: 'vi',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUser: otherUser,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(UserModel currentUser) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text('Chưa có tin nhắn nào'),
          const SizedBox(height: 40),
          _buildSuggestedUsersSection(currentUser),
        ],
      ),
    );
  }

  Widget _buildSuggestedUsersSection(UserModel currentUser) {
    return FutureBuilder<List<UserModel>>(
      future: _getSuggestedUsers(currentUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gợi ý cho bạn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
