import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import 'storage_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final now = Timestamp.now();
    await _sendMessageDocument(
      senderId: senderId,
      receiverId: receiverId,
      message: MessageModel(
        messageId: _uuid.v4(),
        senderId: senderId,
        text: text,
        timestamp: now,
        isRead: false,
      ),
      lastMessage: text,
      timestamp: now,
    );
  }

  Future<void> sendMedia({
    required String senderId,
    required String receiverId,
    required String filePath,
    required String mediaType,
  }) async {
    try {
      final file = File(filePath);
      final mediaUrl = mediaType == 'image'
          ? await StorageService.uploadImage(file)
          : await StorageService.uploadVideo(file);

      if (mediaUrl == null) {
        throw Exception('Lỗi upload media lên Cloudinary');
      }

      final now = Timestamp.now();
      await _sendMessageDocument(
        senderId: senderId,
        receiverId: receiverId,
        message: MessageModel(
          messageId: _uuid.v4(),
          senderId: senderId,
          text: '',
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          timestamp: now,
          isRead: false,
        ),
        lastMessage: mediaType == 'image' ? 'Ảnh' : 'Video',
        timestamp: now,
      );
    } catch (e) {
      throw Exception('Lỗi gửi media: $e');
    }
  }

  Future<void> sendSharedPost({
    required String senderId,
    required String receiverId,
    required String postId,
  }) async {
    try {
      final now = Timestamp.now();
      await _sendMessageDocument(
        senderId: senderId,
        receiverId: receiverId,
        message: MessageModel(
          messageId: _uuid.v4(),
          senderId: senderId,
          text: '',
          sharedPostId: postId,
          timestamp: now,
          isRead: false,
        ),
        lastMessage: 'Bài viết được chia sẻ',
        timestamp: now,
      );
    } catch (e) {
      throw Exception('Lỗi chia sẻ bài viết: $e');
    }
  }

  Stream<List<MessageModel>> getMessages(String userId1, String userId2) {
    final chatId = getChatId(userId1, userId2);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(MessageModel.fromDoc).toList());
  }

  Stream<List<ChatModel>> getChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final chats = snap.docs.map(ChatModel.fromDoc).toList();
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  Future<void> markAsRead(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  Future<void> _sendMessageDocument({
    required String senderId,
    required String receiverId,
    required MessageModel message,
    required String lastMessage,
    required Timestamp timestamp,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    await _upsertChatSummary(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      lastMessage: lastMessage,
      timestamp: timestamp,
    );

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.messageId)
        .set(message.toMap());
  }

  Future<void> _upsertChatSummary({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String lastMessage,
    required Timestamp timestamp,
  }) async {
    await _db.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [senderId, receiverId],
      'lastMessage': lastMessage,
      'lastMessageTime': timestamp,
      'lastSenderId': senderId,
    }, SetOptions(merge: true));
  }
}
