// social/notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ── Core writer ───────────────────────────────────────────────────────────
  static Future<void> _write({
    required String targetUid,
    required String type,
    required String message,
    String? postId,
    String? postImageUrl,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == targetUid) return;

    final myDoc = await _db.collection('users').doc(me.uid).get();
    final myName =
        myDoc.data()?['name'] as String? ?? me.displayName ?? 'Someone';
    final myPhoto = me.photoURL ?? '';

    await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
      'type': type,
      'fromUid': me.uid,
      'fromName': myName,
      'fromPhotoUrl': myPhoto,
      'postId': postId,
      'postImageUrl': postImageUrl,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // ── Follow notification ───────────────────────────────────────────────────
  static Future<void> sendFollowNotification(String targetUid) async {
    await _write(
        targetUid: targetUid,
        type: 'follow',
        message: 'started following you.');
  }

  // ── Like notification ─────────────────────────────────────────────────────
  static Future<void> sendLikeNotification({
    required String targetUid,
    required String postId,
    String? postImageUrl,
  }) async {
    await _write(
        targetUid: targetUid,
        type: 'like',
        message: 'buzzed your post. 🐝',
        postId: postId,
        postImageUrl: postImageUrl);
  }

  // ── Comment notification ──────────────────────────────────────────────────
  static Future<void> sendCommentNotification({
    required String targetUid,
    required String postId,
    required String commentText,
    String? postImageUrl,
  }) async {
    final snippet = commentText.length > 40
        ? '${commentText.substring(0, 40)}…'
        : commentText;
    await _write(
        targetUid: targetUid,
        type: 'comment',
        message: 'commented: "$snippet"',
        postId: postId,
        postImageUrl: postImageUrl);
  }

  // ── Mention notification ──────────────────────────────────────────────────
  // Sent when a user is @mentioned in a buzz caption.
  static Future<void> sendMentionNotification({
    required String targetUid,
    required String postId,
    String? postImageUrl,
  }) async {
    await _write(
        targetUid: targetUid,
        type: 'mention',
        message: 'mentioned you in a buzz. 📣',
        postId: postId,
        postImageUrl: postImageUrl);
  }

  // ── Parse @mentions from text, resolve to UIDs, send notifications ────────
  static Future<void> sendMentionNotifications({
    required String text,
    required String postId,
    String? postImageUrl,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    // Extract all @mention tokens
    final regex = RegExp(r'@([\w]+)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return;

    // Collect unique mention names (preserve original case)
    final mentioned = <String>{};
    for (final m in matches) {
      mentioned.add(m.group(1)!);
    }

    for (final username in mentioned) {
      // Try exact match first, then lowercase
      QuerySnapshot<Map<String, dynamic>> snap = await _db
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();

      // If not found, try lowercase
      if (snap.docs.isEmpty) {
        snap = await _db
            .collection('users')
            .where('name', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) continue;

      final targetUid = snap.docs.first.id;
      if (targetUid == me.uid) continue; // don't notify yourself

      await sendMentionNotification(
        targetUid: targetUid,
        postId: postId,
        postImageUrl: postImageUrl,
      );
    }
  }

  // ── Notifications stream ──────────────────────────────────────────────────
  static Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Mark single notification as read ─────────────────────────────────────
  static Future<void> markRead(String notifId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  // ── Mark all as read ──────────────────────────────────────────────────────
  static Future<void> markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Unread count stream (for nav badge) ───────────────────────────────────
  static Stream<int> unreadCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }
}