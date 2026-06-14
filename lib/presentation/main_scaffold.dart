import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'screens/play/play_screen.dart';
import 'screens/analyze/analyze_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/year/year_screen.dart';
import 'screens/settings/settings_screen.dart';
import '../core/i18n/i18n.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  static const _screens = [
    PlayScreen(),
    AnalyzeScreen(),
    StatsScreen(),
    YearScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watching the provider re-renders the bottom nav when locale changes.
    context.watch<GameProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) {
            context.read<GameProvider>().sfx.tap();
            setState(() => _selectedIndex = i);
          },
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.table_restaurant_outlined, selected: _selectedIndex == 0),
              activeIcon: _NavIcon(icon: Icons.table_restaurant, selected: true),
              label: I18n.t('nav_play'),
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.analytics_outlined, selected: _selectedIndex == 1),
              activeIcon: _NavIcon(icon: Icons.analytics, selected: true),
              label: I18n.t('nav_analyze'),
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.leaderboard_outlined, selected: _selectedIndex == 2),
              activeIcon: _NavIcon(icon: Icons.leaderboard, selected: true),
              label: I18n.t('nav_stats'),
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.timeline_outlined, selected: _selectedIndex == 3),
              activeIcon: _NavIcon(icon: Icons.timeline, selected: true),
              label: I18n.t('nav_year'),
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.tune_outlined, selected: _selectedIndex == 4),
              activeIcon: _NavIcon(icon: Icons.tune, selected: true),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _NavIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (selected)
          Positioned(
            top: -2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
