import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final String? imageUrl;
  final String? mediaUrl;
  final String? mediaType; // 'image' hoặc 'video'
  final String? sharedPostId; // ID của bài viết được share
  final Timestamp timestamp;
  final bool isRead;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.mediaUrl,
    this.mediaType,
    this.sharedPostId,
    required this.timestamp,
    required this.isRead,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      messageId: data['messageId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      sharedPostId: data['sharedPostId'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'sharedPostId': sharedPostId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}

class ChatModel {
  final String chatId;
  final List<String> participants; // [userId1, userId2]
  final String lastMessage;
  final Timestamp lastMessageTime;
  final String lastSenderId;

  ChatModel({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      chatId: data['chatId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      lastSenderId: data['lastSenderId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
    };
  }
}