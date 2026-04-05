import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'report_screen.dart';
import 'recommend_screen.dart';
import 'food_add_screen.dart';

// 아직 구현 전인 탭은 플레이스홀더로 대체
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 48, color: AppColors.gray200),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, color: AppColors.gray400)),
            const SizedBox(height: 4),
            const Text('준비 중이에요', style: TextStyle(fontSize: 13, color: AppColors.gray200)),
          ],
        ),
      ),
    );
  }
}

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
    _screens = [
      HomeScreen(profile: widget.profile),          // [0] 홈
      const CalendarScreen(),                        // [1] 기록
      const SizedBox.shrink(),                       // [2] FAB 자리 — 탭 아님
      ReportScreen(                              // [3] 리포트
        userName: widget.profile.name.isNotEmpty
            ? widget.profile.name
            : '00',
      ),
      RecommendScreen(                               // [4] 추천
        userName: widget.profile.name.isNotEmpty
            ? widget.profile.name
            : '00',
      ),
    ];
  }

  // ── 핵심 수정: _currentIndex(0~4) → IndexedStack index(0~3) 매핑 ──
  // _currentIndex: 0=홈  1=기록  2=FAB(탭 아님)  3=리포트  4=추천
  // IndexedStack :  0=홈  1=기록                  2=리포트  3=추천
  int get _stackIndex {
    switch (_currentIndex) {
      case 0:  return 0; // 홈
      case 1:  return 1; // 기록
      case 2:  return 0; // FAB → 홈 유지
      case 3:  return 2; // 리포트
      case 4:  return 3; // 추천
      default: return 0;
    }
  }

  void _onFabTap() {
    // 현재 탭에 맞는 끼니 기본값 결정
    final hour = DateTime.now().hour;
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
        index: _stackIndex, // ← 수정된 매핑 사용
        children: [
          _screens[0], // IndexedStack[0]: 홈
          _screens[1], // IndexedStack[1]: 기록
          _screens[3], // IndexedStack[2]: 리포트
          _screens[4], // IndexedStack[3]: 추천
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFab() {
    return SizedBox(
      width: 52,
      height: 52,
      child: FloatingActionButton(
        onPressed: _onFabTap,
        backgroundColor: AppColors.green400,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.zero,
      color: AppColors.white,
      elevation: 8,
      notchMargin: 6,
      shape: const CircularNotchedRectangle(),
      child: Row(
        children: [
          _NavItem(icon: Icons.home_rounded,              label: '홈',    index: 0, current: _currentIndex, onTap: _setTab),
          _NavItem(icon: Icons.calendar_month_rounded,    label: '기록',  index: 1, current: _currentIndex, onTap: _setTab),
          const Expanded(child: SizedBox()),              // FAB 자리
          _NavItem(icon: Icons.bar_chart_rounded,         label: '리포트',index: 3, current: _currentIndex, onTap: _setTab),
          _NavItem(icon: Icons.lightbulb_outline_rounded, label: '추천',  index: 4, current: _currentIndex, onTap: _setTab),
        ],
      ),
    );
  }

  void _setTab(int i) => setState(() => _currentIndex = i);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: isActive ? AppColors.green400 : AppColors.gray200),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppColors.green400 : AppColors.gray200,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
