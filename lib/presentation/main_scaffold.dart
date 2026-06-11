import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'screens/play/play_screen.dart';
import 'screens/analyze/analyze_screen.dart';
import 'screens/stats/stats_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
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
          onTap: (i) => setState(() => _selectedIndex = i),
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
              label: 'JUGAR',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.analytics_outlined, selected: _selectedIndex == 1),
              activeIcon: _NavIcon(icon: Icons.analytics, selected: true),
              label: 'ANALIZAR',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.leaderboard_outlined, selected: _selectedIndex == 2),
              activeIcon: _NavIcon(icon: Icons.leaderboard, selected: true),
              label: 'VALORACIÓN',
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
