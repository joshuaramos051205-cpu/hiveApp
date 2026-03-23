// social/follow_service.dart
//
// Firestore structure:
//   users/{uid}/followers/{followerUid}  → { followedAt: Timestamp }
//   users/{uid}/following/{followingUid} → { followedAt: Timestamp }
//
// On every follow, a notification is also written to the target's
// notifications subcollection via NotificationService.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FollowService {
  static final _db = FirebaseFirestore.instance;

  // ── Follow a user ─────────────────────────────────────────────────────────
  static Future<void> follow(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == targetUid) return;

    final batch = _db.batch();

    // Add to target's followers subcollection
    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(myUid),
      {'followedAt': FieldValue.serverTimestamp()},
    );

    // Add to my following subcollection
    batch.set(
      _db.collection('users').doc(myUid).collection('following').doc(targetUid),
      {'followedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();

    // Send follow notification (runs after batch so it doesn't block)
    await NotificationService.sendFollowNotification(targetUid);
  }

  // ── Unfollow a user ───────────────────────────────────────────────────────
  static Future<void> unfollow(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == targetUid) return;

    final batch = _db.batch();

    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(myUid),
    );

    batch.delete(
      _db.collection('users').doc(myUid).collection('following').doc(targetUid),
    );

    await batch.commit();
    // Note: we do NOT delete the notification on unfollow — same as Instagram.
  }

  // ── Is current user following target? (real-time stream) ─────────────────
  static Stream<bool> isFollowingStream(String targetUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  // ── Does target follow current user back? (real-time stream) ─────────────
  // Used to show "Follow Back" vs "Following" in the activity screen.
  static Stream<bool> isFollowingMeStream(String targetUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    // If targetUid is in MY followers subcollection, they follow me
    return _db
        .collection('users')
        .doc(myUid)
        .collection('followers')
        .doc(targetUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  // ── Real-time followers count ─────────────────────────────────────────────
  static Stream<int> followersCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Real-time following count ─────────────────────────────────────────────
  static Stream<int> followingCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── List of follower user docs (for the followers sheet) ──────────────────
  static Stream<List<Map<String, dynamic>>> followersListStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .asyncMap((snap) async {
      final futures = snap.docs.map((d) async {
        final userDoc = await _db.collection('users').doc(d.id).get();
        final data = userDoc.data() ?? {};
        return {
          'uid': d.id,
          'name': data['name'] ?? 'HiVE User',
          'email': data['email'] ?? '',
          'photoUrl': data['photoURL'] ?? '',
        };
      });
      return Future.wait(futures);
    });
  }

  // ── List of following user docs (for the following sheet) ─────────────────
  static Stream<List<Map<String, dynamic>>> followingListStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .asyncMap((snap) async {
      final futures = snap.docs.map((d) async {
        final userDoc = await _db.collection('users').doc(d.id).get();
        final data = userDoc.data() ?? {};
        return {
          'uid': d.id,
          'name': data['name'] ?? 'HiVE User',
          'email': data['email'] ?? '',
          'photoUrl': data['photoURL'] ?? '',
        };
      });
      return Future.wait(futures);
    });
  }
}
