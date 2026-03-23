// profile/profile_screen.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../auth/auth_service.dart';
import '../core/app_theme.dart';
import '../social/follow_service.dart';
import '../profile/user_profile_screen.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'HiVE User';
    final photoUrl = user?.photoURL;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Sliver App Bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.scaffoldBg,
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => _showMenu(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1200), AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.center,
                  child: Text('🍯',
                      style: TextStyle(fontSize: 70, height: 1.2)),
                ),
              ),
            ),
          ),

          // ── Profile Info ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Avatar + Buttons row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarOptions(context, uid),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.primary, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: AppTheme.surfaceBg,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? const Text('🐝',
                                        style: TextStyle(fontSize: 36))
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.scaffoldBg, width: 2),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.black87, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _ActionButton(
                        label: 'Edit Profile',
                        onTap: () => _showEditProfile(context, user),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: 'Share',
                        onTap: () => _shareProfile(context, displayName),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('🐝 Living life in the hive',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          const ClipboardData(text: 'hive.app/me'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Link copied!'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('hive.app/me',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primary)),
                  ),
                  const SizedBox(height: 20),

                  // ── Stats row — ALL counts are real-time from Firestore ──
                  if (uid != null)
                    // Posts count stream
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('buzzes')
                          .where('uid', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, postSnap) {
                        final postCount = postSnap.data?.docs.length ?? 0;

                        // Followers count stream (nested)
                        return StreamBuilder<int>(
                          stream: FollowService.followersCountStream(uid),
                          builder: (context, followersSnap) {
                            final followersCount = followersSnap.data ?? 0;

                            // Following count stream (nested)
                            return StreamBuilder<int>(
                              stream: FollowService.followingCountStream(uid),
                              builder: (context, followingSnap) {
                                final followingCount = followingSnap.data ?? 0;

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat(
                                      label: 'Posts',
                                      value: '$postCount',
                                    ),
                                    _dividerV(),
                                    _Stat(
                                      label: 'Followers',
                                      value: '$followersCount',
                                      onTap: () => _showFollowList(
                                          context, 'Followers', uid),
                                    ),
                                    _dividerV(),
                                    _Stat(
                                      label: 'Following',
                                      value: '$followingCount',
                                      onTap: () => _showFollowList(
                                          context, 'Following', uid),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Tab Bar ──────────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 24)),
                  Tab(
                      icon: Icon(Icons.play_circle_outline_rounded,
                          size: 24)),
                ],
              ),
            ),
          ),
        ],

        // ── Tab Views ──────────────────────────────────────────────────
        body: TabBarView(
          controller: _tabController,
          children: [
            uid != null ? _PostsGrid(uid: uid) : const _EmptyState(),
            const _EmptyState(
              icon: Icons.play_circle_outline_rounded,
              message: 'No reels yet 🐝',
            ),
          ],
        ),
      ),
    );
  }

  Widget _dividerV() =>
      Container(width: 1, height: 36, color: AppTheme.dividerColor);

  // ── Avatar options ────────────────────────────────────────────────────────
  void _showAvatarOptions(BuildContext context, String? uid) {
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
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Profile Photo',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ListTile(
            leading:
                const Icon(Icons.photo_library_rounded, color: Colors.white),
            title: const Text('Choose from library',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await _changeAvatar(uid);
            },
          ),
          if (FirebaseAuth.instance.currentUser?.photoURL != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Remove current photo',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
                if (mounted) setState(() {});
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _changeAvatar(String? uid) async {
    if (uid == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final ref = FirebaseStorage.instance
        .ref()
        .child('avatars')
        .child('$uid.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
    if (mounted) setState(() {});
  }

  // ── Edit Profile ──────────────────────────────────────────────────────────
  void _showEditProfile(BuildContext context, User? user) {
    final nameCtrl = TextEditingController(text: user?.displayName ?? '');
    final bioCtrl =
        TextEditingController(text: '🐝 Living life in the hive');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Edit Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await user?.updateDisplayName(nameCtrl.text.trim());
                    if (mounted) {
                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Profile updated!'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: const Text('Save',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _EditField(label: 'Name', controller: nameCtrl),
            const SizedBox(height: 12),
            _EditField(label: 'Bio', controller: bioCtrl, maxLines: 3),
            const SizedBox(height: 12),
            _EditField(
              label: 'Website',
              controller: TextEditingController(text: 'hive.app/me'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share Profile ─────────────────────────────────────────────────────────
  void _shareProfile(BuildContext context, String name) {
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
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Share Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.link_rounded, color: Colors.white),
            title: const Text('Copy profile link',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: 'hive.app/${name.toLowerCase()}'));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile link copied!'),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_rounded, color: Colors.white),
            title: const Text('Share QR code',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Follow list (real users from Firestore) ───────────────────────────────
  void _showFollowList(BuildContext context, String title, String uid) {
    final stream = title == 'Followers'
        ? FollowService.followersListStream(uid)
        : FollowService.followingListStream(uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const Divider(color: AppTheme.dividerColor),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary));
                  }
                  final users = snap.data!;
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        title == 'Followers'
                            ? 'No followers yet 🐝'
                            : 'Not following anyone yet 🐝',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: ctrl,
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      final targetUid = u['uid'] as String? ?? '';
                      final name = u['name'] as String? ?? 'HiVE User';
                      final email = u['email'] as String? ?? '';
                      final photo = u['photoUrl'] as String? ?? '';
                      return ListTile(
                        onTap: () {
                          if (targetUid.isEmpty) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => UserProfileScreen(uid: targetUid),
                          ));
                        },
                        leading: GestureDetector(
                          onTap: () {
                            if (targetUid.isEmpty) return;
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => UserProfileScreen(uid: targetUid),
                            ));
                          },
                          child: CircleAvatar(
                            backgroundColor: AppTheme.surfaceBg,
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '🐝',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(email,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        trailing: targetUid.isNotEmpty
                            ? _FollowBackButton(targetUid: targetUid)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings / Sign out menu ──────────────────────────────────────────────
  void _showMenu(BuildContext context) {
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
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading:
                const Icon(Icons.settings_outlined, color: Colors.white),
            title: const Text('Settings',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border_rounded,
                color: Colors.white),
            title:
                const Text('Saved', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(context);
              await AuthService.signOut();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Posts Grid ───────────────────────────────────────────────────────────────

class _PostsGrid extends StatelessWidget {
  final String uid;
  const _PostsGrid({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buzzes')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 36),
                  const SizedBox(height: 10),
                  Text(snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot>.from(
            snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aT = (a.data() as Map)['createdAt'];
          final bT = (b.data() as Map)['createdAt'];
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return (bT as dynamic).compareTo(aT as dynamic);
        });

        if (docs.isEmpty) return const _EmptyState();

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final text = data['text'] as String? ?? '';
            final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);

            return GestureDetector(
              onTap: () => _openPost(context, docs[i]),
              child: Container(
                color: AppTheme.surfaceBg,
                child: mediaUrls.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            mediaUrls.first,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: AppTheme.surfaceBg,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppTheme.primary),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => _textTile(text),
                          ),
                          if (mediaUrls.length > 1)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(Icons.collections_rounded,
                                  color: Colors.white, size: 16),
                            ),
                        ],
                      )
                    : _textTile(text),
              ),
            );
          },
        );
      },
    );
  }

  Widget _textTile(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐝', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _openPost(BuildContext context, QueryDocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PostDetailScreen(doc: doc)),
    );
  }
}

// ─── Post Detail Screen ───────────────────────────────────────────────────────

class _PostDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _PostDetailScreen({required this.doc});

  @override
  State<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<_PostDetailScreen> {
  late Map<String, dynamic> data;
  bool _liked = false;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    data = widget.doc.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    _liked = likedBy.contains(_uid);
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
    final ref = FirebaseFirestore.instance
        .collection('buzzes')
        .doc(widget.doc.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final likedBy = List<String>.from(snap['likedBy'] ?? []);
      if (likedBy.contains(_uid)) {
        likedBy.remove(_uid);
      } else {
        likedBy.add(_uid);
      }
      tx.update(ref, {'likedBy': likedBy, 'likes': likedBy.length});
    });
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete buzz?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.primary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('buzzes')
          .doc(widget.doc.id)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
    final text = data['text'] as String? ?? '';
    final likes = data['likes'] as int? ?? 0;
    final displayName = data['displayName'] as String? ?? 'HiVE User';
    final photoUrl = data['photoUrl'] as String? ?? '';
    final isOwn = data['uid'] == _uid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Buzz',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.surfaceBg,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Text('🐝', style: TextStyle(fontSize: 18))
                    : null,
              ),
              title: Text(displayName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Just now',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            if (text.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.5)),
              ),
            if (mediaUrls.isNotEmpty)
              ...mediaUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 300,
                          color: AppTheme.surfaceBg,
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary),
                          ),
                        );
                      },
                    ),
                  )),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(_liked),
                        color: _liked ? AppTheme.primary : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 26, color: Colors.white),
                  const SizedBox(width: 16),
                  const Icon(Icons.send_outlined,
                      size: 25, color: Colors.white),
                  const Spacer(),
                  const Icon(Icons.bookmark_border_rounded,
                      size: 28, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '${likes + (_liked ? 1 : 0)} likes',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({
    this.icon = Icons.grid_on_rounded,
    this.message = 'No buzzes yet 🐝\nPost something!',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Bar Delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.scaffoldBg,
      child: Column(
        children: [
          const Divider(height: 0, color: AppTheme.dividerColor),
          tabBar,
          const Divider(height: 0, color: AppTheme.dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ─── Edit Field ───────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _EditField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Stat Widget ──────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _Stat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

// ─── Follow Back Button ───────────────────────────────────────────────────────

class _FollowBackButton extends StatefulWidget {
  final String targetUid;
  const _FollowBackButton({required this.targetUid});

  @override
  State<_FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends State<_FollowBackButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FollowService.isFollowingStream(widget.targetUid),
      builder: (context, snap) {
        final isFollowing = snap.data ?? false;
        return GestureDetector(
          onTap: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  try {
                    if (isFollowing) {
                      await FollowService.unfollow(widget.targetUid);
                    } else {
                      await FollowService.follow(widget.targetUid);
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isFollowing ? AppTheme.surfaceBg : AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
              border: isFollowing
                  ? Border.all(color: AppTheme.dividerColor)
                  : null,
            ),
            child: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    isFollowing ? 'Following' : 'Follow Back',
                    style: TextStyle(
                      color: isFollowing ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
        );
      },
    );
  }
}