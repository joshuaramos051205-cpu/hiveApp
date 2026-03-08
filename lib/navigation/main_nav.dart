// navigation/main_nav.dart

import 'package:flutter/material.dart';
import '../feed/feed_screen.dart';
import '../explore/explore_screen.dart';
import '../create/create_screen.dart';
import '../activity/activity_screen.dart';
import '../profile/profile_screen.dart';
import '../core/app_theme.dart';
import '../chat/hive_chat_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  // CreateScreen is intentionally NOT in this list — it opens as a modal
  final _screens = const [
    FeedScreen(),
    ExploreScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  // ── Open CreateScreen as a full-screen modal ──────────────────────────
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

    // If post was successful, jump to Profile tab (index 3)
    if (posted == true && mounted) {
      setState(() => _currentIndex = 3);
    }
  }

  void _openChat() {
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

  // Map bottom nav taps — index 2 is the "+" which opens modal
  void _onTabTapped(int i) {
    if (i == 2) {
      _openCreate();
    } else {
      // Shift index to account for removed CreateScreen slot
      setState(() => _currentIndex = i > 2 ? i - 1 : i);
    }
  }

  // Map _currentIndex back to bottom nav highlight
  int get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _BeeChatFAB(onTap: _openChat),
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
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: ''),
            // "+" always looks unselected — it's a modal trigger, not a tab
            BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                activeIcon: Icon(Icons.add_box_outlined),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border_rounded),
                activeIcon: Icon(Icons.favorite_rounded),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: ''),
          ],
        ),
      ),
    );
  }
}


// ─── Bee Chat FAB ─────────────────────────────────────────────────────────────
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
          builder: (_, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ── Hello tooltip ──────────────────────────────────────────
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
                      border:
                      Border.all(color: AppTheme.primary, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('👋', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 5),
                        Text(
                          'Hello!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── FAB Circle ─────────────────────────────────────────────
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