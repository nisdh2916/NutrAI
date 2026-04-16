import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/meal_models.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'ai_chat_screen.dart';

// ── 홈 화면 ──────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final UserProfile profile;

  HomeScreen({super.key, required this.profile});

  // 샘플 식단 데이터 (실제론 DB에서 로드)
  final List<MealRecord> _meals = const [
    MealRecord(
      label: '아침', time: '10:00 AM',
      foods: [
        MealFood(name: '비빔밥 외 2개', carb: 65, protein: 18, fat: 8,  kcal: 410),
        MealFood(name: '김밥',          carb: 48, protein: 12, fat: 6,  kcal: 300),
        MealFood(name: '제육볶음',      carb: 20, protein: 25, fat: 14, kcal: 310),
      ],
    ),
    MealRecord(
      label: '점심', time: '12:00 PM',
      foods: [
        MealFood(name: '비빔밥 외 2개', carb: 70, protein: 20, fat: 10, kcal: 450),
      ],
    ),
    MealRecord(
      label: '저녁', time: '07:00 PM',
      foods: [
        MealFood(name: '비빔밥 외 2개', carb: 60, protein: 22, fat: 12, kcal: 430),
      ],
    ),
  ];

  double get _totalKcal    => _meals.fold(0, (s, m) => s + m.totalKcal);
  double get _totalCarb    => _meals.fold(0, (s, m) => s + m.totalCarb);
  double get _totalProtein => _meals.fold(0, (s, m) => s + m.totalProtein);
  double get _totalFat     => _meals.fold(0, (s, m) => s + m.totalFat);
  double get _goalKcal     => profile.bmr?.roundToDouble() ?? 2000;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isNotEmpty ? profile.name : '사용자';
    final now  = DateTime.now();
    final dateStr = '${now.year}년 ${now.month}월 ${now.day}일';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── 앱바 ──
          SliverAppBar(
            backgroundColor: AppColors.white,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            expandedHeight: 0,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: CircleAvatar(
                backgroundColor: AppColors.surfaceAlt,
                radius: 16,
                child: Text(
                  name.isNotEmpty ? name[0] : 'N',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '어서오세요, $name님',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(0.5),
              child: Divider(height: 0.5, color: AppColors.border),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 오늘의 영양 요약 카드 ──
                _NutritionSummaryCard(
                  totalKcal:    _totalKcal,
                  goalKcal:     _goalKcal,
                  totalCarb:    _totalCarb,
                  totalProtein: _totalProtein,
                  totalFat:     _totalFat,
                ),
                const SizedBox(height: 12),

                // ── AI 코치 카드 ──
                _ChatbotCard(name: name),
                const SizedBox(height: 24),

                // ── 끼니 섹션 제목 ──
                Row(
                  children: [
                    const Text(
                      '오늘 식단',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '전체보기',
                        style: TextStyle(fontSize: 12, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 끼니 카드들 ──
                ..._meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealCard(meal: meal),
                )),

                // ── 새 식단 추가 버튼 ──
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
                  label: const Text(
                    '새 식단 추가',
                    style: TextStyle(fontSize: 14, color: AppColors.accent),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 영양 요약 카드 ────────────────────────────────
class _NutritionSummaryCard extends StatelessWidget {
  final double totalKcal, goalKcal, totalCarb, totalProtein, totalFat;
  const _NutritionSummaryCard({
    required this.totalKcal, required this.goalKcal,
    required this.totalCarb, required this.totalProtein, required this.totalFat,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goalKcal - totalKcal).clamp(0, double.infinity);
    final progress  = (totalKcal / goalKcal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // 상단: 도넛 차트 + 오른쪽 수치
          Row(
            children: [
              // 도넛 차트 (두께 얇게, 중앙 숫자 크게)
              SizedBox(
                width: 110, height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(110, 110),
                      painter: _DonutPainter(
                        carb:    totalCarb,
                        protein: totalProtein,
                        fat:     totalFat,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalKcal.round().toString(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          'kcal',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // 오른쪽 수치
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NutrRow(label: '탄수화물', value: totalCarb,    color: AppColors.carbColor,    unit: 'g'),
                    const SizedBox(height: 10),
                    _NutrRow(label: '단백질',  value: totalProtein,  color: AppColors.proteinColor, unit: 'g'),
                    const SizedBox(height: 10),
                    _NutrRow(label: '지방',    value: totalFat,      color: AppColors.fatColor,     unit: 'g'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${remaining.round()} kcal 남음',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 하단: 목표 달성률 바
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '오늘 목표',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${(progress * 100).round()}%  ${totalKcal.round()} / ${goalKcal.round()} kcal',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutrRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String unit;
  const _NutrRow({required this.label, required this.value, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const Spacer(),
      Text(
        '${value.round()}$unit',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ]);
  }
}

// ── 도넛 차트 CustomPainter ───────────────────────
class _DonutPainter extends CustomPainter {
  final double carb, protein, fat;
  _DonutPainter({required this.carb, required this.protein, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = carb + protein + fat;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 9;
    const strokeW = 10.0;  // 두께 얇게

    final paint = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.butt;

    // 배경 트랙
    paint.color = AppColors.border;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    if (total == 0) return;

    final segments = [
      (carb    / total, AppColors.carbColor),
      (protein / total, AppColors.proteinColor),
      (fat     / total, AppColors.fatColor),
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.04;

    for (final (ratio, color) in segments) {
      final sweep = ratio * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += ratio * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.carb != carb || old.protein != protein || old.fat != fat;
}

// ── AI 코치 카드 ──────────────────────────────────
class _ChatbotCard extends StatelessWidget {
  final String name;
  const _ChatbotCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NutrAI 코치',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '아직 점심 식사를 기록하지 않았어요. 지금 기록할까요?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 끼니 카드 ─────────────────────────────────────
class _MealCard extends StatelessWidget {
  final MealRecord meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 끼니 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
            child: Row(
              children: [
                Text(
                  meal.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  meal.time,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${meal.totalKcal.round()} kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.more_horiz_rounded, color: AppColors.textHint, size: 18),
                ),
              ],
            ),
          ),

          const Divider(height: 0.5, indent: 16, endIndent: 16, color: AppColors.border),

          // 음식 목록
          ...meal.foods.map((food) => _FoodRow(food: food)),

          // 끼니 영양소 요약
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _NutrChip(label: '탄 ${meal.totalCarb.round()}g', color: AppColors.carbColor),
                const SizedBox(width: 6),
                _NutrChip(label: '단 ${meal.totalProtein.round()}g', color: AppColors.proteinColor),
                const SizedBox(width: 6),
                _NutrChip(label: '지 ${meal.totalFat.round()}g', color: AppColors.fatColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final MealFood food;
  const _FoodRow({required this.food});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '탄 ${food.carb.round()}g  단 ${food.protein.round()}g  지 ${food.fat.round()}g',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _NutrChip extends StatelessWidget {
  final String label;
  final Color color;
  const _NutrChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
