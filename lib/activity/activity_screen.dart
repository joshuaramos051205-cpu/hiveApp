// activity/activity_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

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
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white54),
            onPressed: () {},
          )
        ],
      ),
      body: ListView(
        children: [
          _sectionHeader('New'),
          _item(0, 'buzzed your post. 🐝', true),
          _item(1, 'started following you.', false, isFollow: true),

          const Divider(color: AppTheme.dividerColor, indent: 70, height: 8),

          _sectionHeader('This Week'),
          _item(2, 'commented: "That hive aesthetic 🔥"', true),
          _item(3, 'buzzed your post.', true),
          _item(4, 'started following you.', false, isFollow: true),
          _item(5, 'mentioned you in a comment.', true),

          const Divider(color: AppTheme.dividerColor, indent: 70, height: 8),

          _sectionHeader('Suggested for You'),
          _item(6, 'is on HiVE. Follow them to see their posts.', false,
              isFollow: true, isSuggested: true),
          _item(7, 'is on HiVE. Follow them to see their posts.', false,
              isFollow: true, isSuggested: true),
          _item(8, 'is on HiVE. Follow them to see their posts.', false,
              isFollow: true, isSuggested: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title,
      style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: Colors.white),
    ),
  );

  static Widget _item(
      int i,
      String action,
      bool hasThumbnail, {
        bool isFollow = false,
        bool isSuggested = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Avatar with yellow ring for "new"
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                ),
                child: CircleAvatar(
                  radius: 23,
                  backgroundImage:
                  NetworkImage('https://i.pravatar.cc/150?u=hive_act$i'),
                ),
              ),
              if (isSuggested)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppTheme.primary,
                    child: Text('🐝', style: TextStyle(fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(
                    text: 'buzzer_$i ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: action),
                  TextSpan(
                    text: '  ${i + 1}h',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Right side: thumbnail or follow button
          if (hasThumbnail)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                'https://picsum.photos/seed/act$i/100/100',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            )
          else if (isFollow)
            _FollowButton(),
        ],
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: _following ? AppTheme.surfaceBg : AppTheme.primary,
          borderRadius: BorderRadius.circular(10),
          border: _following
              ? Border.all(color: AppTheme.dividerColor)
              : null,
        ),
        child: Text(
          _following ? 'Following' : 'Follow',
          style: TextStyle(
            color: _following ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}