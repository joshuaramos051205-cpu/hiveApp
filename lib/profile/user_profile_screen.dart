// profile/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';

class UserProfileScreen extends StatelessWidget {
  final String uid; // UID of the user to display
  const UserProfileScreen({required this.uid, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
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
          final displayName = data['name'] ?? 'HiVE User';
          final username = data['username'] ?? '';
          final bio = data['bio'] ?? 'No bio yet.';
          final photoUrl = data['photoURL'] as String?;
          final coverUrl = data['coverURL'] as String?;
          final postsCount = data['postsCount'] ?? 0;
          final followersCount = data['followersCount'] ?? 0;
          final followingCount = data['followingCount'] ?? 0;

          final isOwnProfile = uid == currentUid;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
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
                              child:
                                  Text('🍯', style: TextStyle(fontSize: 70))),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.surfaceBg,
                        backgroundImage:
                            photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? const Text('🐝', style: TextStyle(fontSize: 40))
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
                            style:
                                const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(label: 'Posts', value: '$postsCount'),
                          _Stat(label: 'Followers', value: '$followersCount'),
                          _Stat(label: 'Following', value: '$followingCount'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isOwnProfile)
                            _ActionButton(
                                label: 'Post Something',
                                onTap: () {
                                  // TODO: implement new post
                                })
                          else ...[
                            _ActionButton(
                                label: 'Follow',
                                onTap: () {
                                  // TODO: follow/unfollow logic
                                }),
                            const SizedBox(width: 12),
                            _ActionButton(
                                label: 'Message',
                                onTap: () {
                                  // TODO: direct message
                                }),
                          ]
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Posts grid
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
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
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
                          final post = docs[i].data() as Map<String, dynamic>;
                          final mediaUrls =
                              List<String>.from(post['mediaUrls'] ?? []);
                          final text = post['text'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              // TODO: open post detail
                            },
                            child: mediaUrls.isNotEmpty
                                ? Image.network(mediaUrls.first,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.surfaceBg,
                                    child: Center(
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

// ─── Helper Widgets ───────────────────────────────

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
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
