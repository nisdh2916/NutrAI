import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/meal_models.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

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
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppColors.green50,
                radius: 18,
                child: Text(
                  name.isNotEmpty ? name[0] : 'N',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green800),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('어서오세요! $name님', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Divider(height: 0.5, color: AppColors.border),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

                // ── 나만의 챗봇 카드 ──
                _ChatbotCard(name: name),
                const SizedBox(height: 20),

                // ── 끼니 섹션 제목 ──
                Row(
                  children: [
                    const Text('오늘 식단', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('전체보기', style: TextStyle(fontSize: 12, color: AppColors.green400)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── 끼니 카드들 ──
                ..._meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealCard(meal: meal),
                )),

                // ── 새 식단 추가 버튼 ──
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.green400),
                  label: const Text('새 식단 추가하기', style: TextStyle(fontSize: 14, color: AppColors.green400)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.green400, width: 1.5),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // 상단: 도넛 차트 + 오른쪽 수치
          Row(
            children: [
              // 도넛 차트
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const Text('kcal', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // 오른쪽 수치
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NutrRow(label: '탄수화물', value: totalCarb, color: const Color(0xFF5BA4D0), unit: 'g'),
                    const SizedBox(height: 10),
                    _NutrRow(label: '단백질',  value: totalProtein, color: AppColors.green400, unit: 'g'),
                    const SizedBox(height: 10),
                    _NutrRow(label: '지방',    value: totalFat,     color: const Color(0xFFE8A838), unit: 'g'),
                    const SizedBox(height: 10),
                    // 목표 대비
                    Row(children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.gray100, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(
                        '남은 칼로리: ${remaining.round()}kcal',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 하단: 목표 달성률 바
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('오늘 목표', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    '${(totalKcal / goalKcal * 100).clamp(0, 100).round()}%  ${totalKcal.round()} / ${goalKcal.round()} kcal',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (totalKcal / goalKcal).clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: AppColors.gray50,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green400),
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
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const Spacer(),
      Text('${value.round()}$unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
    if (total == 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 8;
    const strokeW = 16.0;

    final paint = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.butt;

    // 배경 트랙
    paint.color = AppColors.gray50;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // 각 영양소 호
    final segments = [
      (carb    / total, const Color(0xFF5BA4D0)),
      (protein / total, AppColors.green400),
      (fat     / total, const Color(0xFFE8A838)),
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.04; // 호 사이 간격 (rad)

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

// ── 챗봇 카드 ─────────────────────────────────────
class _ChatbotCard extends StatelessWidget {
  final String name;
  const _ChatbotCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: 챗봇 화면 이동
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.green50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green100, width: 0.5),
        ),
        child: Row(
          children: [
            // 봇 아이콘
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green100, width: 1),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.green600, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '나만의 챗봇 🌿',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.green800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '아직 점심 식사를 기록하지 않았어요!\n지금 바로 기록해볼까요?',
                    style: const TextStyle(fontSize: 12, color: AppColors.green600, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.green400, size: 20),
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 끼니 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    meal.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(meal.time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                Text(
                  '${meal.totalKcal.round()} kcal',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.more_horiz_rounded, color: AppColors.gray200, size: 20),
                ),
              ],
            ),
          ),

          const Divider(height: 0.5, indent: 16, endIndent: 16, color: AppColors.border),

          // 음식 목록
          ...meal.foods.map((food) => _FoodRow(food: food)),

          // 끼니 합계
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _NutrChip(label: '탄수화물 ${meal.totalCarb.round()}%', color: const Color(0xFF5BA4D0)),
                const SizedBox(width: 6),
                _NutrChip(label: '단백질 ${meal.totalProtein.round()}%', color: AppColors.green400),
                const SizedBox(width: 6),
                _NutrChip(label: '지방 ${meal.totalFat.round()}%', color: const Color(0xFFE8A838)),
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
                Text(food.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  '탄수화물 ${food.carb.round()}g  단백질 ${food.protein.round()}g  지방 ${food.fat.round()}g',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.favorite_border_rounded, size: 18, color: AppColors.gray200),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
