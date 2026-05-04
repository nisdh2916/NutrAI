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
    final name = widget.profile.name.isNotEmpty ? widget.profile.name : '사용자';
    _screens = [
      HomeScreen(profile: widget.profile),
      CalendarScreen(onGoToReport: () => _setTab(3)),
      ReportScreen(userName: name),
      RecommendScreen(userName: name),
    ];
  }

  int get _stackIndex {
    switch (_currentIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 0;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  void _onFabTap() {
    final hour = DateTime.now().hour;
    final label = hour < 10
        ? '아침'
        : hour < 15
            ? '점심'
            : hour < 18
                ? '간식'
                : hour < 22
                    ? '저녁'
                    : '야식';
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
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(children: [
              _NavItem(
                  icon: Icons.home_outlined,
                  iconActive: Icons.home_rounded,
                  label: '홈',
                  index: 0,
                  current: _currentIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.calendar_month_outlined,
                  iconActive: Icons.calendar_month_rounded,
                  label: '기록',
                  index: 1,
                  current: _currentIndex,
                  onTap: _setTab),
              _AddNavAction(onTap: _onFabTap),
              _NavItem(
                  icon: Icons.bar_chart,
                  iconActive: Icons.bar_chart,
                  label: '리포트',
                  index: 3,
                  current: _currentIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.lightbulb_outline_rounded,
                  iconActive: Icons.lightbulb_rounded,
                  label: '추천',
                  index: 4,
                  current: _currentIndex,
                  onTap: _setTab),
            ]),
          ),
        ),
      );

  void _setTab(int i) => setState(() => _currentIndex = i);
}

class _AddNavAction extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNavAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: '음식 추가',
        child: Center(
          child: Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.surface,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, iconActive;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label 탭',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                isActive ? iconActive : icon,
                size: 24,
                color: isActive ? AppColors.text : AppColors.textMuted,
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? AppColors.text : AppColors.textMuted,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
