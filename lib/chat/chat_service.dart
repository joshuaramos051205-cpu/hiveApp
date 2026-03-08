import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String buildChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').snapshots();
  }

  static Future<String> createOrGetChat({
    required String otherUserId,
    required String otherUserName,
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user.');
    }

    final chatId = buildChatId(currentUser.uid, otherUserId);
    final chatRef = _db.collection('chats').doc(chatId);
    final snap = await chatRef.get();

    if (!snap.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, otherUserId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? currentUser.email ?? 'User',
          otherUserId: otherUserName,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user.');
    }

    final clean = text.trim();
    if (clean.isEmpty) return;

    final chatRef = _db.collection('chats').doc(chatId);

    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName ?? currentUser.email ?? 'User',
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'lastMessage': clean,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }
}