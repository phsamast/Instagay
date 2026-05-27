import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
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
    final chatId = getChatId(senderId, receiverId);
    final messageId = _uuid.v4();

    final message = MessageModel(
      messageId: messageId,
      senderId: senderId,
      text: text,
      timestamp: Timestamp.now(),
      isRead: false,
    );


    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());


    await _db.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [senderId, receiverId],
      'lastMessage': text,
      'lastMessageTime': Timestamp.now(),
      'lastSenderId': senderId,
    }, SetOptions(merge: true));
  }

  Future<void> sendMedia({
    required String senderId,
    required String receiverId,
    required String filePath,
    required String mediaType,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final messageId = _uuid.v4();
    
    try {
      // Upload file to Cloudinary
      final file = File(filePath);
      String? mediaUrl;
      
      if (mediaType == 'image') {
        mediaUrl = await StorageService.uploadImage(file);
      } else {
        mediaUrl = await StorageService.uploadVideo(file);
      }
      
      if (mediaUrl == null) {
        throw Exception('Lỗi upload media lên Cloudinary');
      }
      
      // Create message with media
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        text: '',
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        timestamp: Timestamp.now(),
        isRead: false,
      );
      
      // Save message to Firestore
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
      
      // Update chat last message
      final displayText = mediaType == 'image' ? '📷 Ảnh' : '🎥 Video';
      await _db.collection('chats').doc(chatId).set({
        'chatId': chatId,
        'participants': [senderId, receiverId],
        'lastMessage': displayText,
        'lastMessageTime': Timestamp.now(),
        'lastSenderId': senderId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Lỗi gửi media: $e');
    }
  }

  Future<void> sendSharedPost({
    required String senderId,
    required String receiverId,
    required String postId,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final messageId = _uuid.v4();

    try {
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        text: '',
        sharedPostId: postId,
        timestamp: Timestamp.now(),
        isRead: false,
      );

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await _db.collection('chats').doc(chatId).set({
        'chatId': chatId,
        'participants': [senderId, receiverId],
        'lastMessage': '📸 Bài viết được chia sẻ',
        'lastMessageTime': Timestamp.now(),
        'lastSenderId': senderId,
      }, SetOptions(merge: true));
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
}