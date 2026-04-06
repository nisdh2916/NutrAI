import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 현재 프로필 카드 ──
          if (user != null) ...[
            _SectionLabel('현재 프로필'),
            _InfoCard(items: [
              _Item('이름',     user.nickname),
              _Item('성별',     user.gender ?? '—'),
              _Item('나이',     user.age != null ? '${user.age}세' : '—'),
              _Item('키',       user.heightCm != null ? '${user.heightCm}cm' : '—'),
              _Item('몸무게',   user.weightKg != null ? '${user.weightKg}kg' : '—'),
              _Item('BMI',      user.bmi != null
                  ? '${user.bmi!.toStringAsFixed(1)} (${user.bmiCategory})' : '—'),
              _Item('기초대사량', user.bmr != null ? '약 ${user.bmr!.round()}kcal' : '—'),
            ]),
            const SizedBox(height: 24),
          ],

          // ── 프로필 재설정 ──
          _SectionLabel('계정'),
          _ActionTile(
            icon: Icons.person_outline_rounded,
            label: '프로필 재설정',
            sub: '온보딩부터 다시 시작해요',
            color: AppColors.green400,
            onTap: () => _confirmReset(context),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            label: '모든 데이터 삭제',
            sub: '식단 기록과 프로필이 모두 삭제돼요',
            color: Colors.red,
            onTap: () => _confirmReset(context),
          ),
        ],
      ),
    );
  }

  // ── 확인 다이얼로그 ──
  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('프로필 재설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            '모든 식단 기록과 프로필이 삭제되고\n온보딩 화면으로 이동해요.\n계속할까요?',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: AppColors.gray400)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              // AppState.resetUser() 호출 → _RootRouter가 자동으로 온보딩으로 전환
              await context.read<AppState>().resetUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.gray400, letterSpacing: 0.5)),
  );
}

class _Item {
  final String label, value;
  const _Item(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final List<_Item> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Text(e.value.label,
                    style: const TextStyle(fontSize: 14,
                        color: AppColors.textSecondary)),
                const Spacer(),
                Text(e.value.value,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ]),
            ),
            if (!isLast) Divider(height: 0.5, color: AppColors.border,
                indent: 16, endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label,
      required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: color)),
            Text(sub, style: const TextStyle(fontSize: 12,
                color: AppColors.textSecondary)),
          ],
        )),
        Icon(Icons.chevron_right_rounded, size: 18, color: color.withOpacity(0.5)),
      ]),
    ),
  );
}
