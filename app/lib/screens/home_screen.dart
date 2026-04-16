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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '좋은 아침이에요 ☀️';
    if (h < 18) return '맛있는 점심 드셨나요? 🍱';
    return '오늘 하루도 수고했어요 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isNotEmpty ? profile.name : '친구';
    final now  = DateTime.now();
    final dateStr = '${now.month}월 ${now.day}일';

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
                backgroundColor: AppColors.green50,
                radius: 16,
                child: Text(
                  name.isNotEmpty ? name[0] : 'N',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green600,
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name님, $_greeting',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
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
                const SizedBox(height: 16),

                // ── AI 코치 카드 ──
                _ChatbotCard(name: name),
                const SizedBox(height: 24),

                // ── 끼니 섹션 ──
                Row(
                  children: [
                    const Text(
                      '🍽️ 오늘 식단',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        '전체보기',
                        style: TextStyle(fontSize: 13, color: AppColors.green400),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 끼니 카드들 ──
                ..._meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MealCard(meal: meal),
                )),

                // ── 새 식단 추가 버튼 ──
                const SizedBox(height: 4),
                _GradientButton(
                  onTap: () {},
                  label: '+ 식단 기록하기',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 그라디언트 CTA 버튼 ────────────────────────────
class _GradientButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _GradientButton({required this.onTap, required this.label});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.green400.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
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

  String get _encouragement {
    final pct = totalKcal / goalKcal;
    if (pct < 0.3) return '오늘도 잘 시작했어요 🌱';
    if (pct < 0.7) return '균형 잡힌 식단이에요 👍';
    if (pct < 1.0) return '거의 다 왔어요, 잘하고 있어요 ✨';
    return '오늘도 열심히 했어요 🎉';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (totalKcal / goalKcal).clamp(0.0, 1.0);
    final remaining = (goalKcal - totalKcal).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 도넛 차트 (두껍고 둥근 끝)
              SizedBox(
                width: 120, height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
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
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'kcal',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _encouragement,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NutrRow(label: '탄수화물', value: totalCarb,    color: AppColors.carbColor,    unit: 'g'),
                    const SizedBox(height: 8),
                    _NutrRow(label: '단백질',  value: totalProtein,  color: AppColors.proteinColor, unit: 'g'),
                    const SizedBox(height: 8),
                    _NutrRow(label: '지방',    value: totalFat,      color: AppColors.fatColor,     unit: 'g'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 목표 달성률 바
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '목표 ${goalKcal.round()} kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${remaining.round()} kcal 남았어요',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.green100,
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
      Container(
        width: 9, height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const Spacer(),
      Text(
        '${value.round()}$unit',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    ]);
  }
}

// ── 도넛 차트 (두껍게 + round cap) ───────────────
class _DonutPainter extends CustomPainter {
  final double carb, protein, fat;
  _DonutPainter({required this.carb, required this.protein, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = carb + protein + fat;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 10;
    const strokeW = 14.0;

    final paint = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.round;

    // 배경 트랙
    paint.color = AppColors.green100;
    paint.strokeCap = StrokeCap.butt;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.strokeCap = StrokeCap.round;

    if (total == 0) return;

    final segments = [
      (carb    / total, AppColors.carbColor),
      (protein / total, AppColors.proteinColor),
      (fat     / total, AppColors.fatColor),
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.05;

    for (final (ratio, color) in segments) {
      final sweep = ratio * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle + gap / 2,
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.green50,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // 캐릭터 아이콘
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.green400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green400.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '나만의 NutrAI 코치 🌿',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘 점심을 아직 기록 안 했어요!\n같이 기록해볼까요? 😊',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.green300, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── 끼니 카드 (파스텔 배경) ───────────────────────
class _MealCard extends StatelessWidget {
  final MealRecord meal;
  const _MealCard({required this.meal});

  static const _cardColors = {
    '아침': AppColors.morningCard,
    '점심': AppColors.lunchCard,
    '저녁': AppColors.dinnerCard,
  };

  static const _mealEmoji = {
    '아침': '🌅',
    '점심': '☀️',
    '저녁': '🌙',
  };

  @override
  Widget build(BuildContext context) {
    final cardColor = _cardColors[meal.label] ?? AppColors.snackCard;
    final emoji = _mealEmoji[meal.label] ?? '🍽️';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 끼니 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  '$emoji ${meal.label}',
                  style: const TextStyle(
                    fontSize: 14,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),

          const Divider(height: 0.5, indent: 16, endIndent: 16, color: AppColors.border),

          // 음식 목록
          ...meal.foods.map((food) => _FoodRow(food: food)),

          // 영양소 요약
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                _NutrPill(label: '탄 ${meal.totalCarb.round()}g', color: AppColors.carbColor),
                const SizedBox(width: 6),
                _NutrPill(label: '단 ${meal.totalProtein.round()}g', color: AppColors.proteinColor),
                const SizedBox(width: 6),
                _NutrPill(label: '지 ${meal.totalFat.round()}g', color: AppColors.fatColor),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '탄 ${food.carb.round()}g · 단 ${food.protein.round()}g · 지 ${food.fat.round()}g',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.favorite_border_rounded, size: 18, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _NutrPill extends StatelessWidget {
  final String label;
  final Color color;
  const _NutrPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
