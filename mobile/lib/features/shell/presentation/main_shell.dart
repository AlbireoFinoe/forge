import 'package:flutter/material.dart';

import '../../../core/theme/forge_theme.dart';
import '../../auth/data/auth_user.dart';
import '../../home/presentation/home_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../train/presentation/train_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.user, super.key});

  final AuthUser user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(user: widget.user),
          const TrainScreen(),
          const ProgressScreen(),
          ProfileScreen(user: widget.user),
        ],
      ),
      bottomNavigationBar: _ForgeBottomNavigation(
        currentIndex: _currentIndex,
        onSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _ForgeBottomNavigation extends StatelessWidget {
  const _ForgeBottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ForgeColors.surface,
        border: Border(top: BorderSide(color: ForgeColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              _ForgeNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () {
                  onSelected(0);
                },
              ),
              _ForgeNavItem(
                label: 'Train',
                icon: Icons.fitness_center_outlined,
                selectedIcon: Icons.fitness_center,
                selected: currentIndex == 1,
                onTap: () {
                  onSelected(1);
                },
              ),
              _ForgeNavItem(
                label: 'Progress',
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart_rounded,
                selected: currentIndex == 2,
                onTap: () {
                  onSelected(2);
                },
              ),
              _ForgeNavItem(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: currentIndex == 3,
                onTap: () {
                  onSelected(3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgeNavItem extends StatelessWidget {
  const _ForgeNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ForgeColors.primary
        : ForgeColors.textSecondary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ForgeRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 22 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: ForgeColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  selected ? selectedIcon : icon,
                  size: 24,
                  color: foreground,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
