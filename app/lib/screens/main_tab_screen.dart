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
      HomeScreen(profile: widget.profile), // [0] 홈
      const CalendarScreen(),              // [1] 기록
      const SizedBox.shrink(),             // [2] FAB 자리
      ReportScreen(userName: name),        // [3] 리포트
      RecommendScreen(userName: name),     // [4] 추천
    ];
  }

  // _currentIndex: 0=홈  1=기록  2=FAB  3=리포트  4=추천
  // IndexedStack :  0=홈  1=기록          2=리포트  3=추천
  int get _stackIndex {
    switch (_currentIndex) {
      case 0:  return 0;
      case 1:  return 1;
      case 2:  return 0; // FAB → 홈 유지
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
          _screens[0], // 홈
          _screens[1], // 기록
          _screens[3], // 리포트
          _screens[4], // 추천
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFab() => SizedBox(
    width: 46, height: 46,
    child: FloatingActionButton(
      onPressed: _onFabTap,
      backgroundColor: AppColors.accent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 1,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
    ),
  );

  Widget _buildBottomNav() => BottomAppBar(
    height: 64 + MediaQuery.of(context).padding.bottom,
    padding: EdgeInsets.zero,
    color: AppColors.white,
    elevation: 8,
    notchMargin: 6,
    shape: const CircularNotchedRectangle(),
    child: Row(children: [
      _NavItem(iconActive: Icons.home_rounded,           iconInactive: Icons.home_outlined,              label: '홈',    index: 0, current: _currentIndex, onTap: _setTab),
      _NavItem(iconActive: Icons.calendar_month_rounded, iconInactive: Icons.calendar_month_outlined,    label: '기록',  index: 1, current: _currentIndex, onTap: _setTab),
      const Expanded(child: SizedBox()),              // FAB 자리
      _NavItem(iconActive: Icons.bar_chart_rounded,       iconInactive: Icons.bar_chart_outlined,        label: '리포트',index: 3, current: _currentIndex, onTap: _setTab),
      _NavItem(iconActive: Icons.lightbulb_rounded,       iconInactive: Icons.lightbulb_outline_rounded, label: '추천',  index: 4, current: _currentIndex, onTap: _setTab),
    ]),
  );

  void _setTab(int i) => setState(() => _currentIndex = i);
}

class _NavItem extends StatelessWidget {
  final IconData iconActive;
  final IconData iconInactive;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.iconActive,
    required this.iconInactive,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
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
            isActive ? iconActive : iconInactive,
            size: 22,
            color: isActive ? AppColors.accent : AppColors.textHint,
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 10,
            color: isActive ? AppColors.accent : AppColors.textHint,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}
