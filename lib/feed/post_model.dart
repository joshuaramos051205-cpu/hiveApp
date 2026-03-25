// feed/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id, uid, username, userAvatar, imageUrl, caption;
  final int likes, commentsCount;
  final List<String> likedBy, mediaUrls;
  final DateTime? createdAt;
  final String? videoUrl;

  Post({
    required this.id,
    required this.uid,
    required this.username,
    required this.userAvatar,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.likedBy,
    required this.commentsCount,
    required this.mediaUrls,
    this.createdAt,
    this.videoUrl,
  });

  static bool isVideoUrl(String url) => url.toLowerCase().contains('.mp4');

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final urls = List<String>.from(d['mediaUrls'] ?? []);
    return Post(
      id: doc.id,
      uid: d['uid'] ?? '',
      username: d['displayName'] ?? 'HiVE User',
      userAvatar: d['photoUrl'] ?? '',
      imageUrl: urls.isNotEmpty ? urls.first : '',
      caption: d['text'] ?? '',
      likes: d['likes'] ?? 0,
      likedBy: List<String>.from(d['likedBy'] ?? []),
      commentsCount: d['commentsCount'] ?? 0,
      mediaUrls: urls,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// class Comment {
//   final String id, text, username, userAvatar;
//   final DateTime? createdAt;
//   Comment(
//       {required this.id,
//       required this.text,
//       required this.uid,
//       required this.username,
//       required this.userAvatar,
//       this.createdAt});
// }

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
