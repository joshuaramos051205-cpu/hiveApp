// explore/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search the Hive...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textSecondary),
                  suffixIcon: const Icon(Icons.tune_rounded,
                      color: AppTheme.primary, size: 20),
                  filled: true,
                  fillColor: AppTheme.surfaceBg,
                  hintStyle:
                  const TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: ['🔥 Trending', '🐝 Buzz', '🎵 Music', '✈️ Travel', '🍔 Food']
                    .asMap()
                    .entries
                    .map((e) => _Chip(e.value, e.key == 0))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: 24,
                itemBuilder: (context, i) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                      'https://picsum.photos/seed/explore$i/300/300',
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.surfaceBg),
                    ),
                    if (i % 5 == 0)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.play_circle_filled_rounded,
                            color: AppTheme.primary, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  const _Chip(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}