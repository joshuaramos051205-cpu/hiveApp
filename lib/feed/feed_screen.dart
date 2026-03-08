// feed/feed_screen.dart
import 'package:hive_app/chat/users_list_screen.dart';
import 'dart:io';
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
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 26),
            onPressed: () {},
          ),
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
  final DateTime createdAt;

  _Story({
    required this.id,
    required this.uid,
    required this.username,
    required this.userAvatar,
    required this.mediaUrl,
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
      createdAt:
      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Stories expire after 24 hours
  bool get isAlive =>
      DateTime.now().difference(createdAt).inHours < 24;
}

// ─── Stories Row ──────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  /// Upload a new story image for the current user
  Future<void> _addStory(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result =
    await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    // Show uploading indicator
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Uploading story… 🐝'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      final file = File(result.files.single.path!);
      final ref = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Write story doc — visible to ALL users via the stories collection
      await FirebaseFirestore.instance.collection('stories').add({
        'uid': user.uid,
        'username': user.displayName ?? 'HiVE User',
        'userAvatar': user.photoURL ?? '',
        'mediaUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Story posted! 🍯'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to upload story: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
          // Parse + filter expired stories
          final allStories = (snap.data?.docs ?? [])
              .map((d) => _Story.fromDoc(d))
              .where((s) => s.isAlive)
              .toList();

          // Deduplicate: one slot per user (latest story per user)
          final Map<String, _Story> latestByUser = {};
          for (final s in allStories) {
            if (!latestByUser.containsKey(s.uid) ||
                s.createdAt
                    .isAfter(latestByUser[s.uid]!.createdAt)) {
              latestByUser[s.uid] = s;
            }
          }

          // Current user's story (if any) goes first after "Your Story"
          final others = latestByUser.values
              .where((s) => s.uid != currentUid)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final myStory = latestByUser[currentUid];

          return ListView(
            scrollDirection: Axis.horizontal,
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              // ── "Your Story" / Add button ─────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  // Tap: view story if exists, else upload
                  onTap: () {
                    if (myStory != null) {
                      final myStories = allStories
                          .where((s) => s.uid == currentUid)
                          .toList()
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      _openStory(context, myStory, myStories);
                    } else {
                      _addStory(context);
                    }
                  },
                  // Long-press: always add a new story
                  onLongPress: () => _addStory(context),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Gradient ring if current user has an
                              // active story, plain if not
                              gradient: myStory != null
                                  ? const LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  Color(0xFFFF8C00)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : null,
                              color: myStory == null
                                  ? AppTheme.surfaceBg
                                  : null,
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.surfaceBg,
                              backgroundImage: myStory != null
                                  ? NetworkImage(myStory.userAvatar)
                                  : (FirebaseAuth.instance.currentUser
                                  ?.photoURL !=
                                  null
                                  ? NetworkImage(FirebaseAuth
                                  .instance
                                  .currentUser!
                                  .photoURL!)
                                  : null),
                              child: (myStory == null &&
                                  FirebaseAuth.instance.currentUser
                                      ?.photoURL ==
                                      null)
                                  ? const Icon(Icons.add,
                                  color: AppTheme.primary,
                                  size: 26)
                                  : null,
                            ),
                          ),
                          // "+" badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.scaffoldBg,
                                    width: 2),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.black87, size: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your Story',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Other users' stories from Firestore ───────────────
              ...others.map(
                    (story) => Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () =>
                        _openStory(context, story, allStories),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary,
                                Color(0xFFFF8C00)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.surfaceBg,
                            backgroundImage:
                            story.userAvatar.isNotEmpty
                                ? NetworkImage(story.userAvatar)
                                : null,
                            child: story.userAvatar.isEmpty
                                ? const Text('🐝',
                                style: TextStyle(fontSize: 20))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          story.username.length > 9
                              ? '${story.username.substring(0, 8)}…'
                              : story.username,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Full-screen story viewer
  void _openStory(BuildContext context, _Story story,
      List<_Story> allStories) {
    // Collect all stories for this user (could be multiple)
    final userStories =
    allStories.where((s) => s.uid == story.uid).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _StoryViewer(stories: userStories),
      ),
    );
  }
}

// ─── Story Viewer ─────────────────────────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  final List<_Story> stories;
  const _StoryViewer({required this.stories});

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _progress;

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
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _progress.forward(from: 0);
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

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final half = MediaQuery.of(context).size.width / 2;
          if (details.globalPosition.dx < half) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story image
            CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary)),
              errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white54, size: 48)),
            ),

            // Top gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 10,
              right: 10,
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
                          builder: (_, __) => LinearProgressIndicator(
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

            // User info header
            Positioned(
              top: MediaQuery.of(context).padding.top + 22,
              left: 14,
              right: 14,
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
                  Text(
                    story.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgo(story.createdAt),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                  ),
                ],
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
          // 1. Header
          ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
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
            title: Text(
              widget.post.username,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
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