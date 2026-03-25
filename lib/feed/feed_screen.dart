// feed/feed_screen.dart
import 'package:hive_app/chat/users_list_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_theme.dart';
import '../core/video_widget.dart';
import 'post_model.dart';
import 'feed_service.dart';
import 'upload_notifier.dart';
import '../profile/user_profile_screen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

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
            icon:
                const Icon(Icons.send_outlined, color: Colors.white, size: 24),
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
      body: Column(
        children: [
          // ── Upload progress banner ────────────────────────────────────────
          const _UploadBanner(),

          // ── Feed list ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Post>>(
              stream: FeedService.feedStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary));
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
                  itemCount: posts.length,
                  itemBuilder: (context, index) =>
                      _PostCard(post: posts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upload Banner ────────────────────────────────────────────────────────────
// Nagpapakita ng progress bar sa taas ng feed habang nag-uupload.
// Auto-dismisses pagkatapos ng upload.

class _UploadBanner extends StatefulWidget {
  const _UploadBanner();

  @override
  State<_UploadBanner> createState() => _UploadBannerState();
}

class _UploadBannerState extends State<_UploadBanner>
    with SingleTickerProviderStateMixin {
  final _notifier = UploadNotifier.instance;

  late final AnimationController _slideAnim;
  late final Animation<Offset> _slideOffset;

  @override
  void initState() {
    super.initState();
    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideOffset = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnim, curve: Curves.easeOut));

    _notifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onNotifierChanged);
    _slideAnim.dispose();
    super.dispose();
  }

  void _onNotifierChanged() {
    if (_notifier.status == UploadStatus.uploading) {
      _slideAnim.forward();
    } else if (_notifier.status == UploadStatus.idle) {
      _slideAnim.reverse();
    } else {
      // done or error — keep visible then auto-hides via notifier timer
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _notifier,
      builder: (context, _) {
        final status = _notifier.status;
        if (status == UploadStatus.idle) return const SizedBox.shrink();

        final isDone = status == UploadStatus.done;
        final isError = status == UploadStatus.error;

        final Color barColor = isError
            ? Colors.redAccent
            : isDone
                ? Colors.greenAccent
                : AppTheme.primary;

        final String label = isError
            ? 'Upload failed. Please try again.'
            : isDone
                ? 'Buzz posted! ✓'
                : _notifier.label;

        final IconData icon = isError
            ? Icons.error_outline_rounded
            : isDone
                ? Icons.check_circle_outline_rounded
                : Icons.cloud_upload_outlined;

        return SlideTransition(
          position: _slideOffset,
          child: Container(
            color: AppTheme.cardBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  child: isDone || isError
                      ? Container(color: barColor)
                      : LinearProgressIndicator(
                          value: _notifier.progress,
                          backgroundColor: AppTheme.dividerColor,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          minHeight: 2,
                        ),
                ),
                // Label row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      // Animated icon
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: isDone || isError
                            ? Icon(icon,
                                color: barColor,
                                size: 16,
                                key: ValueKey(status))
                            : SizedBox(
                                key: const ValueKey('spinner'),
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  value: _notifier.progress > 0
                                      ? _notifier.progress
                                      : null,
                                  strokeWidth: 2,
                                  color: barColor,
                                  backgroundColor: AppTheme.dividerColor,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            label,
                            key: ValueKey(label),
                            style: TextStyle(
                              color:
                                  isDone || isError ? barColor : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Percentage
                      if (!isDone && !isError)
                        Text(
                          '${(_notifier.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: barColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    ]).animate(CurvedAnimation(parent: _heartAnim, curve: Curves.easeOut));
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
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await FeedService.deletePost(widget.post.id);
              },
            ),
          ListTile(
            leading: const Icon(Icons.link_rounded, color: Colors.white),
            title:
                const Text('Copy link', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.white),
            title: const Text('Report', style: TextStyle(color: Colors.white)),
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

  Widget _buildMedia() {
    final post = widget.post;

    if (post.mediaUrls.isEmpty) return const SizedBox.shrink();

    // Loader function para sa local files
    Widget imageLoader(String path) {
      if (path.isEmpty) return const SizedBox.shrink();

      // 1. Kung Network URL (http) O Base64 Data URL (data:image)
      // Parehong supported ito ng Image.network sa Web at Mobile
      if (path.startsWith('http') || path.startsWith('data:image')) {
        return Image.network(
          path,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(height: 200, color: Colors.grey),
        );
      }

      // 2. Kung Local File Path (Para sa Android/iOS lamang)
      if (!kIsWeb) {
        return Image.file(
          File(path),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(height: 200, color: Colors.grey),
        );
      }

      // Fallback kung may error sa web path
      return Container(
          height: 200,
          color: AppTheme.surfaceBg,
          child: const Icon(Icons.broken_image, color: Colors.white24));
    }

    if (post.mediaUrls.length == 1) {
      return imageLoader(post.mediaUrls.first);
    }

    // Kung marami, gamitin ang pager pero local image loader
    return SizedBox(
      height: 380,
      child: PageView.builder(
        itemCount: post.mediaUrls.length,
        itemBuilder: (_, i) => imageLoader(post.mediaUrls[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedByLatest = widget.post.likedBy.contains(_currentUid);
    final displayLiked = _liked;
    final likeCount = widget.post.likes +
        (displayLiked && !likedByLatest ? 1 : 0) -
        (!displayLiked && likedByLatest ? 1 : 0);

    final hasMedia = widget.post.videoUrl != null ||
        widget.post.mediaUrls.any((u) => !Post.isVideoUrl(u));

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
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            subtitle: Text(
              FeedService.timeAgo(widget.post.createdAt),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white54),
              onPressed: () => _showMore(context),
            ),
          ),

          // 2. Media with double-tap-to-like
          if (hasMedia)
            GestureDetector(
              onDoubleTap: _doubleTapLike,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildMedia(),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: displayLiked ? AppTheme.primary : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showComments(context),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.send_outlined, size: 25, color: Colors.white),
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
                        color: saved ? AppTheme.primary : Colors.white,
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),

          // 5. Caption
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4),
                  children: [
                    TextSpan(
                      text: '${widget.post.username} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),

          // 7. Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              FeedService.timeAgo(widget.post.createdAt).toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.5),
            ),
          ),

          const Divider(
              color: AppTheme.dividerColor, thickness: 0.5, height: 0),
        ],
      ),
    );
  }
}

// ─── Multi-Image Pager ────────────────────────────────────────────────────────

class _MultiImagePager extends StatefulWidget {
  final List<String> imageUrls;
  const _MultiImagePager({required this.imageUrls});

  @override
  State<_MultiImagePager> createState() => _MultiImagePagerState();
}

class _MultiImagePagerState extends State<_MultiImagePager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: widget.imageUrls[i],
              width: double.infinity,
              height: 380,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(height: 380, color: AppTheme.surfaceBg),
              errorWidget: (_, __, ___) =>
                  Container(height: 380, color: AppTheme.surfaceBg),
            ),
          ),
        ),
        // Dot indicators
        Positioned(
          bottom: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.imageUrls.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppTheme.primary : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        // Page counter badge (top-right)
        Positioned(
          top: 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_page + 1}/${widget.imageUrls.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
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
                    child: Text('No comments yet. Be the first! 🐝',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.surfaceBg,
                            backgroundImage: c.userAvatar.isNotEmpty
                                ? NetworkImage(c.userAvatar)
                                : null,
                            child: c.userAvatar.isEmpty
                                ? const Text('🐝',
                                    style: TextStyle(fontSize: 12))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                              fontWeight: FontWeight.w700)),
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
                  backgroundImage:
                      FirebaseAuth.instance.currentUser?.photoURL != null
                          ? NetworkImage(
                              FirebaseAuth.instance.currentUser!.photoURL!)
                          : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? const Text('🐝', style: TextStyle(fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
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
                            strokeWidth: 2, color: AppTheme.primary))
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

class _SmartImage extends StatelessWidget {
  final String path;
  const _SmartImage({required this.path, super.key});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    // 1. Kung Network URL (Internet)
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(height: 250, color: AppTheme.surfaceBg),
      );
    }

    // 2. Kung Base64 Data (Fix para sa Web)
    else if (path.startsWith('data:image')) {
      try {
        final String base64String = path.split(',').last;
        return Image.memory(
          base64Decode(base64String), // Decode text back to image
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
            height: 200,
            color: Colors.grey,
            child: const Icon(Icons.broken_image));
      }
    }

    // 3. Kung Local File Path (Para sa Android/iOS)
    else {
      // Dito hindi mag-eerror dahil Image.file ay tinatawag lang pag hindi kIsWeb
      return Image.file(
        File(path),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            color: AppTheme.surfaceBg,
            child: const Icon(Icons.broken_image, color: Colors.white24)),
      );
    }
  }
}
