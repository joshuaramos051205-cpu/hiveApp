// chat/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Build deterministic chat ID from two UIDs ─────────────────────────────
  static String buildChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // ── All users stream (for new conversation picker) ────────────────────────
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').snapshots();
  }

  // ── My conversations — sorted by latest message, newest first ─────────────
  // Each doc has: participants, participantNames, lastMessage,
  // lastMessageAt, unreadCount_{uid}
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyChats() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  // ── Total unread messages across ALL my chats (for nav badge) ─────────────
  static Stream<int> totalUnreadStream() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final count = (data['unreadCount_$uid'] as num?)?.toInt() ?? 0;
        total += count;
      }
      return total;
    });
  }

  // ── Unread count for a single chat ────────────────────────────────────────
  static int getUnreadCount(Map<String, dynamic> chatData) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return 0;
    return (chatData['unreadCount_$uid'] as num?)?.toInt() ?? 0;
  }

  // ── Mark a chat as read (reset my unread count to 0) ─────────────────────
  static Future<void> markChatRead(String chatId) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('chats').doc(chatId).update({
      'unreadCount_$uid': 0,
    });
  }

  // ── Create or get existing chat ───────────────────────────────────────────
  static Future<String> createOrGetChat({
    required String otherUserId,
    required String otherUserName,
    String otherUserPhoto = '',
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) throw Exception('No signed-in user.');

    final chatId = buildChatId(currentUser.uid, otherUserId);
    final chatRef = _db.collection('chats').doc(chatId);
    final snap = await chatRef.get();

    if (!snap.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, otherUserId],
        'participantNames': {
          currentUser.uid:
              currentUser.displayName ?? currentUser.email ?? 'User',
          otherUserId: otherUserName,
        },
        'participantPhotos': {
          currentUser.uid: currentUser.photoURL ?? '',
          otherUserId: otherUserPhoto,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount_${currentUser.uid}': 0,
        'unreadCount_$otherUserId': 0,
      });
    }

    return chatId;
  }

  // ── Messages stream for a chat ────────────────────────────────────────────
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
      String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  // ── Send a message — increments unread count for the OTHER participant ─────
  static Future<void> sendMessage({
    required String chatId,
    required String text,
    required String otherUserId,
  }) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) throw Exception('No signed-in user.');

    final clean = text.trim();
    if (clean.isEmpty) return;

    final chatRef = _db.collection('chats').doc(chatId);

    // Write message
    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'senderName':
          currentUser.displayName ?? currentUser.email ?? 'User',
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat metadata + increment OTHER user's unread count
    await chatRef.update({
      'lastMessage': clean,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount_$otherUserId': FieldValue.increment(1),
    });
  }

  // ── Get the other participant's UID from a chat doc ───────────────────────
  static String getOtherUid(Map<String, dynamic> chatData) {
    final uid = AuthService.currentUser?.uid ?? '';
    final participants = List<String>.from(chatData['participants'] ?? []);
    return participants.firstWhere((p) => p != uid, orElse: () => '');
  }

  // ── Get the other participant's name ──────────────────────────────────────
  static String getOtherName(Map<String, dynamic> chatData) {
    final otherUid = getOtherUid(chatData);
    final names =
        Map<String, dynamic>.from(chatData['participantNames'] ?? {});
    return names[otherUid]?.toString() ?? 'User';
  }

  // ── Get the other participant's photo ─────────────────────────────────────
  static String getOtherPhoto(Map<String, dynamic> chatData) {
    final otherUid = getOtherUid(chatData);
    final photos =
        Map<String, dynamic>.from(chatData['participantPhotos'] ?? {});
    return photos[otherUid]?.toString() ?? '';
  }
}
