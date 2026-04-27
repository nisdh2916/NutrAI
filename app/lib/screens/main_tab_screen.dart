import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'report_screen.dart';
import 'recommend_screen.dart';
import 'food_add_screen.dart';

class MainTabScreen extends StatefulWidget {
  final UserProfile profile;
  const MainTabScreen({super.key, required this.profile});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final name = widget.profile.name.isNotEmpty ? widget.profile.name : '00';
    _screens = [
      HomeScreen(profile: widget.profile),
      CalendarScreen(onGoToReport: () => _setTab(3)),
      const SizedBox.shrink(),
      ReportScreen(userName: name),
      RecommendScreen(userName: name),
    ];
  }

  int get _stackIndex {
    switch (_currentIndex) {
      case 0:  return 0;
      case 1:  return 1;
      case 2:  return 0;
      case 3:  return 2;
      case 4:  return 3;
      default: return 0;
    }
  }

  void _onFabTap() {
    final hour  = DateTime.now().hour;
    final label = hour < 10 ? '아침' : hour < 15 ? '점심' : '저녁';
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FoodAddScreen(initialMealLabel: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: [
          _screens[0],
          _screens[1],
          _screens[3],
          _screens[4],
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFab() => SizedBox(
    width: 52, height: 52,
    child: FloatingActionButton(
      onPressed: _onFabTap,
      backgroundColor: AppColors.brand,
      elevation: 0,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    ),
  );

  Widget _buildBottomNav() => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      boxShadow: [
        BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -4)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 60,
        child: Row(children: [
          _NavItem(icon: Icons.home_outlined,             iconActive: Icons.home_rounded,              label: '홈',    index: 0, current: _currentIndex, onTap: _setTab),
          _NavItem(icon: Icons.calendar_month_outlined,   iconActive: Icons.calendar_month_rounded,    label: '기록',  index: 1, current: _currentIndex, onTap: _setTab),
          const Expanded(child: SizedBox()),
          _NavItem(icon: Icons.bar_chart_outlined,        iconActive: Icons.bar_chart_rounded,         label: '리포트',index: 3, current: _currentIndex, onTap: _setTab),
          _NavItem(icon: Icons.lightbulb_outline_rounded, iconActive: Icons.lightbulb_rounded,         label: '추천',  index: 4, current: _currentIndex, onTap: _setTab),
        ]),
      ),
    ),
  );

  void _setTab(int i) => setState(() => _currentIndex = i);
}

class _NavItem extends StatelessWidget {
  final IconData icon, iconActive;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon, required this.iconActive,
    required this.label, required this.index,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            isActive ? iconActive : icon,
            size: 24,
            color: isActive ? AppColors.text : AppColors.textMuted,
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.text : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.01,
          )),
        ]),
      ),
    );
  }
}
