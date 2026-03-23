// activity/activity_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_theme.dart';
import '../social/follow_service.dart';
import '../social/notification_service.dart';
import '../profile/user_profile_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Activity',
          style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white54),
            tooltip: 'Mark all as read',
            onPressed: () => NotificationService.markAllRead(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: NotificationService.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load notifications.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🐝', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'No activity yet.\nStart buzzing!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.6),
                  ),
                ],
              ),
            );
          }
          final unread =
              docs.where((d) => d.data()['isRead'] == false).toList();
          final read =
              docs.where((d) => d.data()['isRead'] != false).toList();

          return ListView(
            children: [
              if (unread.isNotEmpty) ...[
                _sectionHeader('New'),
                ...unread.map((doc) => _NotifItem(doc: doc)),
                const Divider(color: AppTheme.dividerColor, indent: 70, height: 8),
              ],
              if (read.isNotEmpty) ...[
                _sectionHeader(unread.isEmpty ? 'Activity' : 'Earlier'),
                ...read.map((doc) => _NotifItem(doc: doc)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  static Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white)),
      );
}

class _NotifItem extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _NotifItem({required this.doc});

  void _goToProfile(BuildContext context, String fromUid) {
    if (fromUid.isEmpty) return;
    NotificationService.markRead(doc.id);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(uid: fromUid)));
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final type = data['type'] as String? ?? '';
    final fromUid = data['fromUid'] as String? ?? '';
    final fromName = data['fromName'] as String? ?? 'Someone';
    final fromPhoto = data['fromPhotoUrl'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final postImageUrl = data['postImageUrl'] as String?;
    final isRead = data['isRead'] as bool? ?? true;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: () => _goToProfile(context, fromUid),
      child: Container(
        decoration: BoxDecoration(
          border: !isRead
              ? const Border(
                  left: BorderSide(color: AppTheme.primary, width: 3))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(!isRead ? 13 : 16, 9, 16, 9),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _goToProfile(context, fromUid),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRead ? Colors.transparent : AppTheme.primary,
                  ),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: AppTheme.surfaceBg,
                    backgroundImage: fromPhoto.isNotEmpty
                        ? NetworkImage(fromPhoto)
                        : null,
                    child: fromPhoto.isEmpty
                        ? Text(
                            fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.4),
                    children: [
                      TextSpan(
                        text: '$fromName ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: message),
                      if (createdAt != null)
                        TextSpan(
                          text: '  ${_timeAgo(createdAt)}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (type == 'follow' && fromUid.isNotEmpty)
                _FollowBackButton(targetUid: fromUid)
              else if (postImageUrl != null && postImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(postImageUrl,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: AppTheme.surfaceBg,
                          )),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
