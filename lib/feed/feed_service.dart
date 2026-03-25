import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'post_model.dart';
import 'upload_notifier.dart';
import '../social/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class FeedService {
  static final List<Post> _localPosts = [];

  // Storage para sa comments: Key ay buzzId, Value ay List ng Comments
  static final Map<String, List<Comment>> _localComments = {};

  static final _streamController = StreamController<List<Post>>.broadcast();
  static final _commentsController =
      StreamController<Map<String, List<Comment>>>.broadcast();

  static Stream<List<Post>> feedStream() {
    Timer(const Duration(milliseconds: 500), () {
      if (!_streamController.isClosed)
        _streamController.add(List.from(_localPosts));
    });
    return _streamController.stream;
  }

  static Future<void> uploadBuzzFast({
    required String text,
    required String audience,
    required List<PlatformFile> files,
    required Function(double) onProgress,
  }) async {
    final notifier = UploadNotifier.instance;
    final user = FirebaseAuth.instance.currentUser; // Identity mo
    final String postId = DateTime.now().millisecondsSinceEpoch.toString();

    notifier.start(files.isEmpty ? 'Posting...' : 'Saving files...');

    try {
      List<String> savedPaths = [];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        if (kIsWeb) {
          if (file.bytes != null) {
            String base64String = base64Encode(file.bytes!);
            savedPaths.add(
                'data:image/${file.extension ?? 'jpg'};base64,$base64String');
          }
        } else {
          if (file.path != null) {
            final Directory directory =
                await getApplicationDocumentsDirectory();
            final String newPath =
                '${directory.path}/buzz_${postId}_$i.${file.extension ?? 'jpg'}';
            await File(file.path!).copy(newPath);
            savedPaths.add(newPath);
          }
        }
        notifier.updateProgress((i + 1) / files.length);
      }

      final newPost = Post(
        id: postId,
        uid: user?.uid ?? "user_me",
        username: user?.displayName ?? "HiVE User",
        userAvatar: user?.photoURL ?? "",
        imageUrl: savedPaths.isNotEmpty ? savedPaths.first : '',
        mediaUrls: savedPaths,
        caption: text,
        likes: 0,
        likedBy: [],
        commentsCount: 0,
        createdAt: DateTime.now(),
      );

      _localPosts.insert(0, newPost);
      _streamController.add(List.from(_localPosts));
      notifier.finish();
    } catch (e) {
      notifier.fail();
    }
  }

  // --- COMMENT LOGIC (FIXED) ---

  static Stream<List<Comment>> commentsStream(String buzzId) {
    // Nag-e-emit ng bagong listahan tuwing may mag-co-comment
    return _commentsController.stream.map((map) => map[buzzId] ?? []);
  }

  static Future<void> addComment(String buzzId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    final String commentId = DateTime.now().millisecondsSinceEpoch.toString();

    final newComment = Comment(
      id: commentId,
      uid: user?.uid ?? "user_me",
      username: user?.displayName ?? "HiVE User",
      userAvatar: user?.photoURL ?? "",
      text: text,
      createdAt: DateTime.now(),
    );

    // 1. I-save ang comment sa local map
    if (_localComments[buzzId] == null) {
      _localComments[buzzId] = [];
    }
    _localComments[buzzId]!.add(newComment);
    _commentsController.add(Map.from(_localComments));

    // 2. I-update ang commentsCount ng Post sa listahan
    final postIdx = _localPosts.indexWhere((p) => p.id == buzzId);
    if (postIdx != -1) {
      final p = _localPosts[postIdx];
      _localPosts[postIdx] = Post(
        id: p.id, uid: p.uid, username: p.username, userAvatar: p.userAvatar,
        imageUrl: p.imageUrl, mediaUrls: p.mediaUrls, caption: p.caption,
        likes: p.likes, likedBy: p.likedBy,
        commentsCount: _localComments[buzzId]!.length, // Update count
        createdAt: p.createdAt,
      );
      _streamController.add(List.from(_localPosts));
    }
  }

  // --- LIKE LOGIC (FIXED) ---
  static Future<void> toggleLike(String buzzId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "user_me";
    final idx = _localPosts.indexWhere((p) => p.id == buzzId);
    if (idx != -1) {
      final p = _localPosts[idx];
      List<String> newLikedBy = List.from(p.likedBy);
      if (newLikedBy.contains(uid)) {
        newLikedBy.remove(uid);
      } else {
        newLikedBy.add(uid);
      }
      _localPosts[idx] = Post(
        id: p.id,
        uid: p.uid,
        username: p.username,
        userAvatar: p.userAvatar,
        imageUrl: p.imageUrl,
        mediaUrls: p.mediaUrls,
        caption: p.caption,
        likes: newLikedBy.length,
        likedBy: newLikedBy,
        commentsCount: p.commentsCount,
        createdAt: p.createdAt,
      );
      _streamController.add(List.from(_localPosts));
    }
  }

  static Future<void> toggleSave(String id) async {}
  static Stream<bool> isSavedStream(String id) => Stream.value(false);
  static Future<void> deletePost(String id) async {}
  static String timeAgo(DateTime? dt) => 'just now';
}
