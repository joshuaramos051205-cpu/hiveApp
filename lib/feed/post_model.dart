// feed/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;           // Firestore doc ID
  final String uid;          // author UID
  final String username;
  final String userAvatar;
  final String imageUrl;
  final String? videoUrl;
  final String caption;
  final int likes;
  final List<String> likedBy;
  final int commentsCount;
  final List<String> mediaUrls;
  final DateTime? createdAt;

  Post({
    required this.id,
    required this.uid,
    required this.username,
    required this.userAvatar,
    required this.imageUrl,
    this.videoUrl,
    required this.caption,
    required this.likes,
    required this.likedBy,
    required this.commentsCount,
    required this.mediaUrls,
    this.createdAt,
  });

  /// Build from a Firestore document
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final uid = d['uid'] as String? ?? '';
    final id = doc.id;
    final mediaUrls = List<String>.from(d['mediaUrls'] ?? []);

    return Post(
      id: id,
      uid: uid,
      username: d['displayName'] as String? ?? 'HiVE User',
      userAvatar: d['photoUrl'] as String? ?? '',
      // Use first media URL as image; fallback to a deterministic picsum
      imageUrl: mediaUrls.isNotEmpty
          ? mediaUrls.first
          : 'https://picsum.photos/seed/$id/600/600',
      videoUrl: null, // wire up when Storage video URLs are added
      caption: d['text'] as String? ?? '',
      likes: (d['likes'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(d['likedBy'] ?? []),
      commentsCount: (d['commentsCount'] as num?)?.toInt() ?? 0,
      mediaUrls: mediaUrls,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ─── Comment model ────────────────────────────────────────────────────────────

class Comment {
  final String id;
  final String uid;
  final String username;
  final String userAvatar;
  final String text;
  final DateTime? createdAt;

  Comment({
    required this.id,
    required this.uid,
    required this.username,
    required this.userAvatar,
    required this.text,
    this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      username: d['displayName'] as String? ?? 'HiVE User',
      userAvatar: d['photoUrl'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}