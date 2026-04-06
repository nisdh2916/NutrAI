import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'main_tab_screen.dart';

class ProfileSummaryScreen extends StatelessWidget {
  final UserProfile profile;
  const ProfileSummaryScreen({super.key, required this.profile});

  String get _bmiText {
    final b = profile.bmi;
    if (b == null) return '—';
    return '${b.toStringAsFixed(1)} (${profile.bmiCategory})';
  }

  String get _bmrText {
    final b = profile.bmr;
    if (b == null) return '—';
    return '약 ${b.round()}kcal';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isNotEmpty ? profile.name : '사용자';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$name님은 이런 사람이군요!',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          // ── 기본 설정 카드 ──
          _SummaryCard(
            title: '기본 설정',
            items: [
              _InfoItem('성별', profile.gender == '남' ? '남성' : '여성'),
              _InfoItem('키', profile.height != null ? '${profile.height}cm' : '—'),
              _InfoItem('몸무게', profile.weight != null ? '${profile.weight}kg' : '—'),
              _InfoItem('나이', profile.age != null ? '${profile.age}세' : '—'),
              _InfoItem('BMI', _bmiText),
              _InfoItem('기초대사량(BMR)', _bmrText),
            ],
          ),
          const SizedBox(height: 24),

          // ── 사용자 커스텀 설정 카드 ──
          _SummaryCard(
            title: '사용자 커스텀 설정',
            items: [
              _InfoItem('목표', profile.goal.isNotEmpty ? profile.goal : '—'),
              // 추후 챗봇 or 추가 설정 화면에서 수집한 값으로 교체
              _InfoItem('운동 빈도', '—'),
              _InfoItem('알레르기', '—'),
              _InfoItem('식단 취향', '—'),
              _InfoItem('식습관 특성', '—'),
              _InfoItem('기대 효과', '—'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _SummaryBottomBar(
        onEdit: () => Navigator.pop(context),
        onComplete: () async {
          // DB에 사용자 저장
          final appState = context.read<AppState>();
          await appState.saveUser(
            nickname:  profile.name.isNotEmpty ? profile.name : '사용자',
            gender:    profile.gender,
            age:       profile.age,
            heightCm:  profile.height,
            weightKg:  profile.weight,
            targetKcal: profile.bmr,
          );
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainTabScreen(profile: profile)),
            (route) => false,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _SummaryCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 항목 목록
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 불릿
                const Padding(
                  padding: EdgeInsets.only(top: 5, right: 8),
                  child: CircleAvatar(
                    radius: 3,
                    backgroundColor: AppColors.textSecondary,
                  ),
                ),
                // 레이블
                Text(
                  '${item.label}: ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                // 값
                Expanded(
                  child: Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _SummaryBottomBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  const _SummaryBottomBar({required this.onEdit, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 설정 수정 (아웃라인)
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            child: const Text(
              '설정 수정',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),

          // 사용자 등록 완료 (초록)
          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green400,
              foregroundColor: AppColors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              '사용자 등록 완료',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
