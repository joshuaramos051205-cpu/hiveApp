// chat/users_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../core/app_theme.dart';
import 'chat_service.dart';
import 'user_chat_screen.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        title: const Text(
          'Messages',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'New message',
            onPressed: () => _showNewMessageSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ChatService.getMyChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load messages.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort client-side by lastMessageAt descending — no index needed
          final sorted = [...docs];
          sorted.sort((a, b) {
            final aT = (a.data()['lastMessageAt'] as Timestamp?)?.toDate();
            final bT = (b.data()['lastMessageAt'] as Timestamp?)?.toDate();
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return bT.compareTo(aT);
          });

          final activeChats = sorted
              .where((d) =>
                  (d.data()['lastMessage'] as String? ?? '').isNotEmpty)
              .toList();

          if (activeChats.isEmpty) {
            return _EmptyInbox(
                onNewMessage: () => _showNewMessageSheet(context));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: activeChats.length,
            separatorBuilder: (_, __) => const Divider(
                color: AppTheme.dividerColor, height: 1, indent: 76),
            itemBuilder: (context, i) {
              final doc = activeChats[i];
              return _ChatTile(
                chatId: doc.id,
                data: doc.data(),
                myUid: myUid,
              );
            },
          );
        },
      ),
    );
  }

  void _showNewMessageSheet(BuildContext context) {
    final myUid = AuthService.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, ctrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            const Text('New Message',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 8),
            const Divider(color: AppTheme.dividerColor),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ChatService.getAllUsers(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary));
                  }

                  final users = snap.data!.docs
                      .where((d) => d.id != myUid)
                      .toList();

                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No other users yet.',
                          style: TextStyle(
                              color: AppTheme.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    controller: ctrl,
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i].data();
                      final uid = users[i].id;
                      final name = u['name'] as String? ?? 'User';
                      final photo = u['photoURL'] as String? ?? '';
                      final email = u['email'] as String? ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.surfaceBg,
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(email,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        onTap: () async {
                          // Capture navigator BEFORE closing sheet
                          final nav = Navigator.of(context);
                          Navigator.pop(sheetContext);
                          final chatId =
                              await ChatService.createOrGetChat(
                            otherUserId: uid,
                            otherUserName: name,
                            otherUserPhoto: photo,
                          );
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => UserChatScreen(
                                chatId: chatId,
                                title: name,
                                otherUserId: uid,
                              ),
                            ),
                          );
                        },
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
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> data;
  final String myUid;

  const _ChatTile({
    required this.chatId,
    required this.data,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = ChatService.getOtherName(data);
    final otherPhoto = ChatService.getOtherPhoto(data);
    final otherUid = ChatService.getOtherUid(data);
    final lastMsg = data['lastMessage'] as String? ?? '';
    final unread = ChatService.getUnreadCount(data);
    final lastAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
    final timeStr = _timeLabel(lastAt);
    final isUnread = unread > 0;

    return InkWell(
      onTap: () async {
        await ChatService.markChatRead(chatId);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserChatScreen(
              chatId: chatId,
              title: otherName,
              otherUserId: otherUid,
            ),
          ),
        );
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.surfaceBg,
                  backgroundImage: otherPhoto.isNotEmpty
                      ? NetworkImage(otherPhoto)
                      : null,
                  child: otherPhoto.isEmpty
                      ? Text(
                          otherName.isNotEmpty
                              ? otherName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.scaffoldBg, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isUnread ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread
                          ? Colors.white70
                          : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isUnread
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: isUnread
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                if (isUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Empty Inbox ──────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onNewMessage;
  const _EmptyInbox({required this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: const Center(
              child: Text('💬', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with\nsomeone in the hive.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onNewMessage,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Send a message 🐝',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
