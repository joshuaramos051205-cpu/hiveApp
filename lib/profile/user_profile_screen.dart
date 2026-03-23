// profile/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import '../social/follow_service.dart';
import '../chat/chat_service.dart';
import '../chat/user_chat_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String uid;
  const UserProfileScreen({required this.uid, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = uid == currentUid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('User not found 😢',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final displayName = data['name'] as String? ?? 'HiVE User';
          final username = data['username'] as String? ?? '';
          final bio = data['bio'] as String? ?? 'No bio yet.';
          final photoUrl = data['photoURL'] as String?;
          final coverUrl = data['coverURL'] as String?;

          return CustomScrollView(
            slivers: [
              // ── Cover / App Bar ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: coverUrl != null
                      ? Image.network(coverUrl, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1A1200), AppTheme.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                              child: Text('🍯',
                                  style: TextStyle(fontSize: 70))),
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Avatar ──────────────────────────────────────────
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.surfaceBg,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? const Text('🐝',
                                style: TextStyle(fontSize: 40))
                            : null,
                      ),
                      const SizedBox(height: 12),

                      Text(displayName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      if (username.isNotEmpty)
                        Text('@$username',
                            style: const TextStyle(
                                color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(bio,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),

                      // ── Stats — all real-time from Firestore ────────────
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('buzzes')
                            .where('uid', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, postSnap) {
                          final postsCount =
                              postSnap.data?.docs.length ?? 0;
                          return StreamBuilder<int>(
                            stream:
                                FollowService.followersCountStream(uid),
                            builder: (context, followersSnap) {
                              final followersCount =
                                  followersSnap.data ?? 0;
                              return StreamBuilder<int>(
                                stream: FollowService
                                    .followingCountStream(uid),
                                builder: (context, followingSnap) {
                                  final followingCount =
                                      followingSnap.data ?? 0;
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _Stat(
                                          label: 'Posts',
                                          value: '$postsCount'),
                                      _Stat(
                                          label: 'Followers',
                                          value: '$followersCount'),
                                      _Stat(
                                          label: 'Following',
                                          value: '$followingCount'),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── Action buttons ──────────────────────────────────
                      if (isOwnProfile)
                        _ActionButton(
                          label: 'Edit Profile',
                          isPrimary: false,
                          onTap: () => Navigator.pop(context),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Follow / Unfollow button
                            StreamBuilder<bool>(
                              stream: FollowService.isFollowingStream(uid),
                              builder: (context, snap) {
                                final isFollowing = snap.data ?? false;
                                return _FollowButton(
                                  isFollowing: isFollowing,
                                  onTap: () async {
                                    if (isFollowing) {
                                      await FollowService.unfollow(uid);
                                    } else {
                                      await FollowService.follow(uid);
                                    }
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            // Message button
                            _ActionButton(
                              label: 'Message',
                              isPrimary: false,
                              onTap: () async {
                                final name = data['name'] as String? ??
                                    'User';
                                final photo =
                                    data['photoURL'] as String? ?? '';
                                final chatId = await ChatService
                                    .createOrGetChat(
                                  otherUserId: uid,
                                  otherUserName: name,
                                  otherUserPhoto: photo,
                                );
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserChatScreen(
                                      chatId: chatId,
                                      title: name,
                                      otherUserId: uid,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Posts grid ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('buzzes')
                      .where('uid', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, postSnap) {
                    if (!postSnap.hasData) {
                      return const SliverToBoxAdapter(
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary)));
                    }

                    final docs = postSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text('No posts yet 🐝',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                          ),
                        ),
                      );
                    }

                    return SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final post = docs[i].data()
                              as Map<String, dynamic>;
                          final mediaUrls = List<String>.from(
                              post['mediaUrls'] ?? []);

                          return GestureDetector(
                            onTap: () {},
                            child: mediaUrls.isNotEmpty
                                ? Image.network(mediaUrls.first,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.surfaceBg,
                                    child: const Center(
                                        child: Text('🐝',
                                            style: TextStyle(
                                                color: Colors.white))),
                                  ),
                          );
                        },
                        childCount: docs.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Follow Button ────────────────────────────────────────────────────────────

class _FollowButton extends StatefulWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                widget.onTap();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isFollowing
              ? AppTheme.surfaceBg
              : AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          border: widget.isFollowing
              ? Border.all(color: AppTheme.dividerColor)
              : null,
        ),
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(
                widget.isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: widget.isFollowing
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  const _ActionButton(
      {required this.label,
      required this.onTap,
      this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: AppTheme.dividerColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: isPrimary ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }
}