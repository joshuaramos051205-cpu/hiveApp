// feed/feed_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_model.dart';

class FeedService {
  static final _db = FirebaseFirestore.instance;

  // ── Feed stream (all buzzes, newest first) ────────────────────────────────
  static Stream<List<Post>> feedStream() {
    return _db
        .collection('buzzes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromFirestore).toList());
  }

  // ── Toggle like ────────────────────────────────────────────────────────────
  // Uses a Firestore transaction so the count is always accurate,
  // even with concurrent users.
  static Future<void> toggleLike(String buzzId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('buzzes').doc(buzzId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final likedBy = List<String>.from(snap['likedBy'] ?? []);
      final alreadyLiked = likedBy.contains(uid);

      if (alreadyLiked) {
        likedBy.remove(uid);
      } else {
        likedBy.add(uid);
      }

      tx.update(ref, {
        'likedBy': likedBy,
        'likes': likedBy.length,
      });
    });
  }

  // ── Toggle save ────────────────────────────────────────────────────────────
  // Saved posts stored under users/{uid}/saved/{buzzId}
  static Future<void> toggleSave(String buzzId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('users').doc(uid).collection('saved').doc(buzzId);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'savedAt': FieldValue.serverTimestamp()});
    }
  }

  // ── Check if current user saved a post ────────────────────────────────────
  static Stream<bool> isSavedStream(String buzzId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(uid)
        .collection('saved')
        .doc(buzzId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  // ── Comments stream ────────────────────────────────────────────────────────
  static Stream<List<Comment>> commentsStream(String buzzId) {
    return _db
        .collection('buzzes')
        .doc(buzzId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Comment.fromFirestore).toList());
  }

  // ── Add comment ───────────────────────────────────────────────────────────
  static Future<void> addComment(String buzzId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final buzzRef = _db.collection('buzzes').doc(buzzId);
    final commentRef = buzzRef.collection('comments').doc();

    final batch = _db.batch();

    batch.set(commentRef, {
      'uid': user.uid,
      'displayName': user.displayName ?? 'HiVE User',
      'photoUrl': user.photoURL ?? '',
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment commentsCount on the parent buzz
    batch.update(buzzRef, {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ── Delete own post ───────────────────────────────────────────────────────
  static Future<void> deletePost(String buzzId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('buzzes').doc(buzzId);
    final snap = await ref.get();

    // Only allow deletion if it's the current user's post
    if (snap.exists && snap['uid'] == uid) {
      await ref.delete();
    }
  }

  // ── Relative timestamp ────────────────────────────────────────────────────
  static String timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}