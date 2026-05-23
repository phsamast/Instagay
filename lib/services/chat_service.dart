import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';

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