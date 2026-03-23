// feed/feed_screen.dart
import 'package:hive_app/chat/users_list_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_theme.dart';
import '../core/video_widget.dart';
import 'post_model.dart';
import 'feed_service.dart';
import '../profile/user_profile_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Row(children: [
          const Text('🐝', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          const Text(
            'HiVE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              fontSize: 26,
              letterSpacing: 2,
            ),
          ),
        ]),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.notifications_none_rounded,
          //       color: Colors.white, size: 26),
          //   onPressed: () {},
          // ),
          IconButton(
            icon: const Icon(Icons.send_outlined,
                color: Colors.white, size: 24),
            onPressed: () {
               Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const UsersListScreen(),
    ),
  );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: FeedService.feedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('🐝', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('No buzzes yet',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Follow people or post your first buzz!',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length + 1, // +1 for stories row
            itemBuilder: (context, index) {
              if (index == 0) return const _StoriesRow();
              return _PostCard(post: posts[index - 1]);
            },
          );
        },
      ),
    );
  }
}

// ─── Story Model ──────────────────────────────────────────────────────────────

class _Story {
  final String id;
  final String uid;
  final String username;
  final String userAvatar;
  final String mediaUrl;
  final String caption;
  final DateTime createdAt;

  _Story({
    required this.id,
    required this.uid,
    required this.username,
    required this.userAvatar,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
  });

  factory _Story.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Story(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      username: d['username'] as String? ?? 'HiVE User',
      userAvatar: d['userAvatar'] as String? ?? '',
      mediaUrl: d['mediaUrl'] as String? ?? '',
      caption: d['caption'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isAlive => DateTime.now().difference(createdAt).inHours < 24;
}

// ─── Stories Row ──────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  Future<void> _addStory(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show caption dialog first
    String caption = '';
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final captionCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Add Story',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add a caption (optional)',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: captionCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What\'s the buzz?',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                onChanged: (v) => caption = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pick Photo',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;
    if (!context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.single;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('Uploading story… 🐝'),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));

    try {
      final ext = (pf.extension ?? 'jpg').toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext');

      if (kIsWeb || pf.bytes != null) {
        final bytes = pf.bytes ?? await File(pf.path!).readAsBytes();
        await ref.putData(bytes,
            SettableMetadata(contentType: 'image/$ext'));
      } else {
        await ref.putFile(File(pf.path!));
      }

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('stories').add({
        'uid': user.uid,
        'username': user.displayName ?? 'HiVE User',
        'userAvatar': user.photoURL ?? '',
        'mediaUrl': url,
        'caption': caption.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'viewedBy': [],
      });

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: const Text('Story posted! 🍯'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _deleteStory(BuildContext context, String storyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete story?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .delete();
    }
  }

  void _openStory(BuildContext context, _Story story,
      List<_Story> allStories) {
    final userStories = allStories
        .where((s) => s.uid == story.uid)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _StoryViewer(
          stories: userStories,
          onDelete: (id) => _deleteStory(context, id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SizedBox(
      height: 100,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          final allStories = (snap.data?.docs ?? [])
              .map((d) => _Story.fromDoc(d))
              .where((s) => s.isAlive)
              .toList();

          // Deduplicate: one slot per user (latest story per user)
          final Map<String, _Story> latestByUser = {};
          for (final s in allStories) {
            if (!latestByUser.containsKey(s.uid) ||
                s.createdAt.isAfter(latestByUser[s.uid]!.createdAt)) {
              latestByUser[s.uid] = s;
            }
          }

          final myStory = latestByUser[currentUid];
          final others = latestByUser.values
              .where((s) => s.uid != currentUid)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              // ── "Your Story" bubble ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () {
                    if (myStory != null) {
                      final myStories = allStories
                          .where((s) => s.uid == currentUid)
                          .toList()
                        ..sort((a, b) =>
                            a.createdAt.compareTo(b.createdAt));
                      _openStory(context, myStory, allStories);
                    } else {
                      _addStory(context);
                    }
                  },
                  onLongPress: () => _addStory(context),
                  child: _StoryBubble(
                    story: myStory,
                    label: 'Your Story',
                    isOwn: true,
                    isSeen: false,
                    currentUserPhoto:
                        FirebaseAuth.instance.currentUser?.photoURL,
                  ),
                ),
              ),

              // ── Other users' stories ─────────────────────────────────
              ...others.map((story) => Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => _openStory(context, story, allStories),
                      child: _StoryBubble(
                        story: story,
                        label: story.username.length > 9
                            ? '${story.username.substring(0, 8)}…'
                            : story.username,
                        isOwn: false,
                        isSeen: (story.id.isNotEmpty) &&
                            ((snap.data?.docs
                                    .firstWhere((d) => d.id == story.id,
                                        orElse: () => snap.data!.docs.first)
                                    .data() as Map<String, dynamic>)[
                                'viewedBy'] as List?)
                                ?.contains(currentUid) ==
                            true,
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ─── Story Bubble ─────────────────────────────────────────────────────────────

class _StoryBubble extends StatelessWidget {
  final _Story? story;
  final String label;
  final bool isOwn;
  final bool isSeen;
  final String? currentUserPhoto;

  const _StoryBubble({
    required this.story,
    required this.label,
    required this.isOwn,
    required this.isSeen,
    this.currentUserPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasStory = story != null;
    final avatarUrl = isOwn
        ? (story?.userAvatar ?? currentUserPhoto ?? '')
        : (story?.userAvatar ?? '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Gradient ring — yellow if unseen story, grey if seen/no story
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory && !isSeen
                    ? const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFFFF8C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasStory && isSeen
                    ? Colors.white24
                    : (!hasStory ? AppTheme.surfaceBg : null),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.surfaceBg,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: Colors.white54, size: 26)
                    : null,
              ),
            ),
            // "+" badge for own story slot
            if (isOwn)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppTheme.scaffoldBg, width: 2),
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.black87, size: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:
                hasStory && !isSeen ? Colors.white : AppTheme.textSecondary,
            fontWeight:
                hasStory && !isSeen ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Story Viewer ─────────────────────────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  final List<_Story> stories;
  final Future<void> Function(String storyId) onDelete;
  const _StoryViewer(
      {required this.stories, required this.onDelete});

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _progress;
  final _replyCtrl = TextEditingController();
  bool _showReply = false;
  final String _myUid =
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _progress.forward();
    _markViewed();
  }

  void _markViewed() {
    final story = widget.stories[_index];
    if (story.uid == _myUid) return; // don't mark own story
    FirebaseFirestore.instance
        .collection('stories')
        .doc(story.id)
        .update({
      'viewedBy': FieldValue.arrayUnion([_myUid]),
    }).catchError((_) {});
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _progress.forward(from: 0);
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _progress.forward(from: 0);
    }
  }

  Future<void> _sendReply(String replyText) async {
    if (replyText.trim().isEmpty) return;
    final story = widget.stories[_index];
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    // Send as a chat message to the story owner
    final chatId = [me.uid, story.uid]..sort();
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId.join('_'));

    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      await chatRef.set({
        'participants': [me.uid, story.uid],
        'participantNames': {
          me.uid: me.displayName ?? 'User',
          story.uid: story.username,
        },
        'participantPhotos': {
          me.uid: me.photoURL ?? '',
          story.uid: story.userAvatar,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount_${me.uid}': 0,
        'unreadCount_${story.uid}': 0,
      });
    }

    await chatRef.collection('messages').add({
      'senderId': me.uid,
      'senderName': me.displayName ?? 'User',
      'text': '📸 Replied to your story: $replyText',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await chatRef.update({
      'lastMessage': '📸 Replied to your story: $replyText',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount_${story.uid}': FieldValue.increment(1),
    });

    _replyCtrl.clear();
    setState(() => _showReply = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Reply sent! 🐝'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    final isOwn = story.uid == _myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapDown: (details) {
          if (_showReply) return;
          final half = MediaQuery.of(context).size.width / 2;
          if (details.globalPosition.dx < half) {
            _prev();
          } else {
            _next();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Story image ────────────────────────────────────────────
            CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primary)),
              errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white54, size: 48)),
            ),

            // ── Top gradient ───────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Bottom gradient ────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 180,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Progress bars ──────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 10, right: 10,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i == _index
                            ? AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) =>
                                    LinearProgressIndicator(
                                  value: _progress.value,
                                  backgroundColor: Colors.white38,
                                  color: Colors.white,
                                  minHeight: 2.5,
                                ),
                              )
                            : LinearProgressIndicator(
                                value: i < _index ? 1.0 : 0.0,
                                backgroundColor: Colors.white38,
                                color: Colors.white,
                                minHeight: 2.5,
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── User header ────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 22,
              left: 14, right: 14,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.surfaceBg,
                    backgroundImage: story.userAvatar.isNotEmpty
                        ? NetworkImage(story.userAvatar)
                        : null,
                    child: story.userAvatar.isEmpty
                        ? const Text('🐝',
                            style: TextStyle(fontSize: 14))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story.username,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text(_timeAgo(story.createdAt),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Delete button (own story only)
                  if (isOwn)
                    GestureDetector(
                      onTap: () async {
                        await widget.onDelete(story.id);
                        if (mounted) Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 20),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),

            // ── Caption ────────────────────────────────────────────────
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: _showReply ? 100 : 80,
                left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    story.caption,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ── Views count (own story) ────────────────────────────────
            if (isOwn)
              Positioned(
                bottom: 30, left: 16,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .doc(story.id)
                      .snapshots(),
                  builder: (context, snap) {
                    final views = snap.hasData && snap.data!.exists
                        ? ((snap.data!.data()
                                as Map<String, dynamic>)['viewedBy']
                            as List?)
                            ?.length ?? 0
                        : 0;
                    return Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text('$views view${views == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    );
                  },
                ),
              ),

            // ── Reply bar (other users' stories) ──────────────────────
            if (!isOwn)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12, right: 12, top: 8,
                    bottom:
                        MediaQuery.of(context).viewInsets.bottom + 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showReply = true);
                            _progress.stop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white38, width: 1),
                            ),
                            child: _showReply
                                ? TextField(
                                    controller: _replyCtrl,
                                    autofocus: true,
                                    style: const TextStyle(
                                        color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Reply to ${story.username}…',
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (v) => _sendReply(v),
                                  )
                                : Text(
                                    'Reply to ${story.username}…',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14),
                                  ),
                          ),
                        ),
                      ),
                      if (_showReply) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              _sendReply(_replyCtrl.text),
                          child: Container(
                            width: 44, height: 44,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.black, size: 20),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            // Quick emoji react
                            await _sendReply('❤️');
                          },
                          child: const Text('❤️',
                              style: TextStyle(fontSize: 28)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}


// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Post post;
  const _PostCard({required this.post, super.key});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  bool _showHeart = false;

  late final AnimationController _heartAnim;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedBy.contains(_currentUid);

    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(
        CurvedAnimation(parent: _heartAnim, curve: Curves.easeOut));
    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartAnim);
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
    await FeedService.toggleLike(widget.post.id);
  }

  Future<void> _doubleTapLike() async {
    if (!_liked) await _toggleLike();
    setState(() => _showHeart = true);
    _heartAnim.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openProfile(BuildContext context) {
    if (widget.post.uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(uid: widget.post.uid),
      ),
    );
  }

  void _showMore(BuildContext context) {
    final isOwn = widget.post.uid == _currentUid;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          if (isOwn)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Delete buzz',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await FeedService.deletePost(widget.post.id);
              },
            ),
          ListTile(
            leading:
            const Icon(Icons.link_rounded, color: Colors.white),
            title: const Text('Copy link',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading:
            const Icon(Icons.flag_outlined, color: Colors.white),
            title: const Text('Report',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(buzzId: widget.post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedByLatest = widget.post.likedBy.contains(_currentUid);
    final displayLiked = _liked;
    final likeCount = widget.post.likes +
        (displayLiked && !likedByLatest ? 1 : 0) -
        (!displayLiked && likedByLatest ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      color: AppTheme.scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header — tap avatar or name to visit profile
          ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: GestureDetector(
              onTap: () => _openProfile(context),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.surfaceBg,
                  backgroundImage: widget.post.userAvatar.isNotEmpty
                      ? NetworkImage(widget.post.userAvatar)
                      : null,
                  child: widget.post.userAvatar.isEmpty
                      ? const Text('🐝', style: TextStyle(fontSize: 16))
                      : null,
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () => _openProfile(context),
              child: Text(
                widget.post.username,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            subtitle: Text(
              FeedService.timeAgo(widget.post.createdAt),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            trailing: IconButton(
              icon:
              const Icon(Icons.more_horiz, color: Colors.white54),
              onPressed: () => _showMore(context),
            ),
          ),

          // 2. Media with double-tap
          GestureDetector(
            onDoubleTap: _doubleTapLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.post.videoUrl != null)
                  VideoWidget(url: widget.post.videoUrl!)
                else
                  CachedNetworkImage(
                    imageUrl: widget.post.imageUrl,
                    height: 380,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        height: 380, color: AppTheme.surfaceBg),
                    errorWidget: (_, __, ___) => Container(
                        height: 380, color: AppTheme.surfaceBg),
                  ),
                if (_showHeart)
                  AnimatedBuilder(
                    animation: _heartAnim,
                    builder: (_, __) => Opacity(
                      opacity: _heartOpacity.value,
                      child: Transform.scale(
                        scale: _heartScale.value,
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 90),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Actions
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      displayLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(displayLiked),
                      color: displayLiked
                          ? AppTheme.primary
                          : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showComments(context),
                  child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 26,
                      color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.send_outlined,
                    size: 25, color: Colors.white),
                const Spacer(),
                StreamBuilder<bool>(
                  stream: FeedService.isSavedStream(widget.post.id),
                  builder: (context, snap) {
                    final saved = snap.data ?? false;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        FeedService.toggleSave(widget.post.id);
                      },
                      child: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 28,
                        color: saved
                            ? AppTheme.primary
                            : Colors.white,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '${likeCount.clamp(0, 999999)} likes',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),

          // 5. Caption
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 2),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(
                    text: '${widget.post.username} ',
                    style:
                    const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: widget.post.caption),
                ],
              ),
            ),
          ),

          // 6. Comments hint
          if (widget.post.commentsCount > 0)
            GestureDetector(
              onTap: () => _showComments(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                child: Text(
                  'View all ${widget.post.commentsCount} comments',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Text('View all comments',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),

          // 7. Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              FeedService.timeAgo(widget.post.createdAt)
                  .toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.5),
            ),
          ),

          const Divider(
              color: AppTheme.dividerColor,
              thickness: 0.5,
              height: 0),
        ],
      ),
    );
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String buzzId;
  const _CommentsSheet({required this.buzzId});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_commentCtrl.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await FeedService.addComment(widget.buzzId, _commentCtrl.text);
    _commentCtrl.clear();
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          const Text('Comments',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const Divider(color: AppTheme.dividerColor),
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: FeedService.commentsStream(widget.buzzId),
              builder: (context, snap) {
                final comments = snap.data ?? [];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                        'No comments yet. Be the first! 🐝',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.surfaceBg,
                            backgroundImage:
                            c.userAvatar.isNotEmpty
                                ? NetworkImage(c.userAvatar)
                                : null,
                            child: c.userAvatar.isEmpty
                                ? const Text('🐝',
                                style:
                                TextStyle(fontSize: 12))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4),
                                    children: [
                                      TextSpan(
                                          text: '${c.username} ',
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w700)),
                                      TextSpan(text: c.text),
                                    ],
                                  ),
                                ),
                                if (c.createdAt != null)
                                  Text(
                                    FeedService.timeAgo(c.createdAt),
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(color: AppTheme.dividerColor, height: 0),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.surfaceBg,
                  backgroundImage: FirebaseAuth
                      .instance.currentUser?.photoURL !=
                      null
                      ? NetworkImage(FirebaseAuth
                      .instance.currentUser!.photoURL!)
                      : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL ==
                      null
                      ? const Text('🐝',
                      style: TextStyle(fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                _submitting
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary))
                    : TextButton(
                  onPressed: _submit,
                  child: const Text('Post',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}