// navigation/main_nav.dart

import 'package:flutter/material.dart';
import '../feed/feed_screen.dart';
import '../explore/explore_screen.dart';
import '../create/create_screen.dart';
import '../activity/activity_screen.dart';
import '../profile/profile_screen.dart';
import '../core/app_theme.dart';
import '../chat/hive_chat_screen.dart';
import '../social/notification_service.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  // Nav: 0=Home  1=Explore  2=+(modal)  3=Activity  4=Profile
  // Screens: 0=Feed  1=Explore  2=Activity  3=Profile
  final _screens = const [
    FeedScreen(),
    ExploreScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  Future<void> _openCreate() async {
    final posted = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CreateScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
        fullscreenDialog: true,
      ),
    );
    if (posted == true && mounted) {
      setState(() => _currentIndex = 3); // jump to Profile after post
    }
  }

  void _openBeeBot() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HiveChatScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // Nav: 0=Home, 1=Explore, 2=+(modal), 3=Activity, 4=Profile
  void _onTabTapped(int i) {
    if (i == 2) {
      _openCreate();
      return;
    }
    final screenIndex = i > 2 ? i - 1 : i;
    setState(() => _currentIndex = screenIndex);
  }

  int get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _BeeChatFAB(onTap: _openBeeBot),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.scaffoldBg,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: const Color(0xFF555555),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            // 0 — Home
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '',
            ),
            // 1 — Explore
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: '',
            ),
            // 2 — Create (modal, never highlighted)
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined),
              activeIcon: Icon(Icons.add_box_outlined),
              label: '',
            ),
            // 3 — Activity (with unread badge)
            BottomNavigationBarItem(
              icon: _ActivityNavIcon(isSelected: _navIndex == 3),
              label: '',
            ),
            // 4 — Profile
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity Nav Icon with Unread Badge ─────────────────────────────────────

class _ActivityNavIcon extends StatelessWidget {
  final bool isSelected;
  const _ActivityNavIcon({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.unreadCountStream(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return _BadgeIcon(
          icon: isSelected
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: count,
          isSelected: isSelected,
        );
      },
    );
  }
}

// ─── Reusable Badge Icon ──────────────────────────────────────────────────────

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isSelected;

  const _BadgeIcon({
    required this.icon,
    required this.count,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon,
            color:
                isSelected ? AppTheme.primary : const Color(0xFF555555)),
        if (count > 0)
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: count > 9 ? 4 : 5,
                vertical: 2,
              ),
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.scaffoldBg, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── BeeBot FAB ───────────────────────────────────────────────────────────────

class _BeeChatFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _BeeChatFAB({required this.onTap});
  @override
  State<_BeeChatFAB> createState() => _BeeChatFABState();
}

class _BeeChatFABState extends State<_BeeChatFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                bottom: _hovered ? 72 : 60,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hovered ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.primary, width: 1.2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🐝', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 5),
                        Text('BeeBot AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.5),
                      blurRadius: _hovered ? 22 : 16,
                      spreadRadius: _hovered ? 3 : 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🐝', style: TextStyle(fontSize: 30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}