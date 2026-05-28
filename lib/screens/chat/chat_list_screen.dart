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

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
    if (doc.exists) return UserModel.fromDoc(doc);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectUserScreen()),
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
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Chưa có tin nhắn nào'),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return FutureBuilder<UserModel?>(
                      future: _getOtherUser(chat.chatId, currentUser.uid),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(child: Icon(Icons.person)),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
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
}
