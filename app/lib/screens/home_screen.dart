import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/meal_models.dart';
import '../models/db_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'ai_chat_screen.dart';
import 'food_add_screen.dart';

// ── 홈 화면 ──────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onGoToCalendar;
  final VoidCallback? onGoToSettings;

  const HomeScreen({super.key, required this.profile, this.onGoToCalendar, this.onGoToSettings});

  static void _showMealDetail(BuildContext context, MealWithFoods meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealDetailSheet(
        meal: meal,
        onDelete: () async {
          await context.read<AppState>().deleteMeal(meal.meal.id!);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  static MealRecord _toMealRecord(MealWithFoods m) {
    DateTime? dt;
    try { dt = DateTime.parse(m.meal.eatenAt); } catch (_) {}
    final timeStr = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    return MealRecord(
      label: m.meal.label,
      time: timeStr,
      foods: m.foods.map((f) => MealFood(
        name: f.food.foodName,
        carb: f.totalCarbG,
        protein: f.totalProteinG,
        fat: f.totalFatG,
        kcal: f.totalKcal,
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state        = context.watch<AppState>();
    final mealRecords  = state.todayMeals.map(_toMealRecord).toList();

    final totalKcal    = state.todayKcal;
    final totalCarb    = state.todayCarbG;
    final totalProtein = state.todayProteinG;
    final totalFat     = state.todayFatG;
    final goalKcal     = profile.bmr?.roundToDouble() ?? 2000;

    final recordedLabels  = mealRecords.map((m) => m.label).toSet();
    const standardMeals   = ['아침', '점심', '저녁'];
    final unrecordedMeals = standardMeals.where((m) => !recordedLabels.contains(m)).toList();

    final name    = profile.name.isNotEmpty ? profile.name : '사용자';
    final now     = DateTime.now();
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];
    final dateStr = '${now.month}월 ${now.day}일 $weekday요일';
    final todayIdx = now.weekday - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── 헤더 ──
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.bg,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0] : 'N',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted, letterSpacing: -0.01)),
                    Text('$name님, 안녕하세요', style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.text, letterSpacing: -0.02)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textSub, size: 22),
                  onPressed: onGoToSettings,
                ),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── DailyOverviewCard ──
                _DailyOverviewCard(
                  totalKcal:    totalKcal,
                  goalKcal:     goalKcal,
                  totalCarb:    totalCarb,
                  totalProtein: totalProtein,
                  totalFat:     totalFat,
                ),
                const SizedBox(height: 12),

                // ── 맞춤 팁 ──
                _TipBanner(),
                const SizedBox(height: 28),

                // ── 오늘 식단 섹션 헤더 ──
                _SectionHeader(title: '오늘 식단', action: '전체보기', onAction: onGoToCalendar),

                // ── 기록된 끼니 카드 ──
                ...state.todayMeals.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealCard(
                    meal: _toMealRecord(m),
                    onMoreTap: () => _showMealDetail(context, m),
                  ),
                )),

                // ── 미기록 끼니 카드 ──
                ...unrecordedMeals.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EmptyMealCard(
                    type: type,
                    recordedCount: mealRecords.length,
                    onRecord: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => FoodAddScreen(initialMealLabel: type),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 12),

                // ── 연속 기록 카드 ──
                _StreakCard(todayIndex: todayIdx),
              ]),
            ),
          ),
        ],
      ),

      // ── 플로팅 AI 코치 버튼 ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: SizedBox(
          width: 58, height: 58,
          child: FloatingActionButton(
            heroTag: 'home_chat_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            ),
            backgroundColor: AppColors.surface,
            elevation: 0,
            shape: const CircleBorder(),
            child: Stack(children: [
              const Center(child: Icon(Icons.smart_toy_outlined,
                  color: AppColors.brand, size: 28)),
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── DailyOverviewCard ────────────────────────────
class _DailyOverviewCard extends StatelessWidget {
  final double totalKcal, goalKcal, totalCarb, totalProtein, totalFat;
  const _DailyOverviewCard({
    required this.totalKcal, required this.goalKcal,
    required this.totalCarb, required this.totalProtein, required this.totalFat,
  });

  @override
  Widget build(BuildContext context) {
    final remaining    = (goalKcal - totalKcal).clamp(0, double.infinity).round();
    final achievePct   = (totalKcal / goalKcal * 100).clamp(0, 100).round();
    final dinnerGuide  = remaining.clamp(0, 700);

    final carbPct    = goalKcal > 0 ? (totalCarb * 4 / goalKcal * 100).clamp(0, 100) : 0.0;
    final proteinPct = goalKcal > 0 ? (totalProtein * 4 / goalKcal * 100).clamp(0, 100) : 0.0;
    final fatPct     = goalKcal > 0 ? (totalFat * 9 / goalKcal * 100).clamp(0, 100) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card2,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.carb, AppColors.protein, AppColors.fat,
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 112, height: 112,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: const Size(112, 112),
                    painter: _DonutPainter(
                      carb: totalCarb, protein: totalProtein, fat: totalFat,
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      totalKcal.round().toString(),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.text, letterSpacing: -0.03),
                    ),
                    Text(
                      '/ ${goalKcal.round()} kcal',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(children: [
                _NutrientRow(
                  color: AppColors.carb, label: '탄수화물',
                  value: totalCarb.round(), unit: 'g',
                  pct: carbPct.toDouble(), goal: (goalKcal * 0.55 / 4).round(),
                ),
                const SizedBox(height: 10),
                _NutrientRow(
                  color: AppColors.protein, label: '단백질',
                  value: totalProtein.round(), unit: 'g',
                  pct: proteinPct.toDouble(), goal: (goalKcal * 0.20 / 4).round(),
                ),
                const SizedBox(height: 10),
                _NutrientRow(
                  color: AppColors.fat, label: '지방',
                  value: totalFat.round(), unit: 'g',
                  pct: fatPct.toDouble(), goal: (goalKcal * 0.25 / 9).round(),
                ),
              ])),
            ]),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: AppColors.lineSoft),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘 남은 칼로리',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(remaining.toString(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                                  color: AppColors.text, letterSpacing: -0.03)),
                          const SizedBox(width: 3),
                          const Text('kcal', style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                        ]),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$achievePct% 달성',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.brandText)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (totalKcal > goalKcal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '권장 칼로리를 초과했어요!',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626), letterSpacing: -0.01),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '목표보다 ${(totalKcal - goalKcal).round()}kcal 더 섭취했어요',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                            color: Color(0xFFEF4444), height: 1.3),
                      ),
                    ],
                  )),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: AppColors.brand),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '저녁은 ${dinnerGuide}kcal 이하를 추천해요',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.brandText, letterSpacing: -0.01),
                      ),
                      const SizedBox(height: 1),
                      const Text('단백질이 살짝 부족해요 · 닭가슴살 추천',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                              color: AppColors.brandText, height: 1.3)),
                    ],
                  )),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── NutrientRow ──────────────────────────────────
class _NutrientRow extends StatelessWidget {
  final Color color;
  final String label, unit;
  final int value, goal;
  final double pct;
  const _NutrientRow({
    required this.color, required this.label,
    required this.value, required this.unit,
    required this.pct, required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final over      = pct > 100;
    final barColor  = over ? AppColors.red : color;
    final valColor  = over ? const Color(0xFFDC2626) : AppColors.text;
    return Column(children: [
      Row(children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textSub, letterSpacing: -0.01)),
        if (over) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('초과', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
          ),
        ],
        const Spacer(),
        RichText(text: TextSpan(children: [
          TextSpan(text: '$value',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: valColor, letterSpacing: -0.03,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          TextSpan(text: unit,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          TextSpan(text: ' /$goal$unit',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled)),
        ])),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0, 1),
          minHeight: 5,
          backgroundColor: AppColors.lineSoft,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    ]);
  }
}

// ── DonutPainter ─────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double carb, protein, fat;
  const _DonutPainter({required this.carb, required this.protein, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = carb + protein + fat;
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 8;
    const strokeW = 14.0;
    const gap     = 0.04;

    final track = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..color      = AppColors.lineSoft;
    canvas.drawCircle(Offset(cx, cy), r, track);

    final segs = [
      (carb    / total, AppColors.carb),
      (protein / total, AppColors.protein),
      (fat     / total, AppColors.fat),
    ];
    double start = -math.pi / 2;
    final p = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap  = StrokeCap.butt;

    for (final (ratio, color) in segs) {
      final sweep = ratio * 2 * math.pi - gap;
      if (sweep <= 0) { start += ratio * 2 * math.pi; continue; }
      p.color = color;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start, sweep, false, p);
      start += ratio * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.carb != carb || old.protein != protein || old.fat != fat;
}

// ── 맞춤 팁 배너 ─────────────────────────────────
class _TipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFFEF9E7)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFCD34D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.lightbulb_rounded,
            size: 20, color: Color(0xFF92400E)),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 맞춤 팁',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E), letterSpacing: 0.04)),
          SizedBox(height: 2),
          Text('오늘 걸음 수가 평소보다 적어요',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF78350F), letterSpacing: -0.01)),
          SizedBox(height: 1),
          Text('저녁은 가볍게 · 채소 위주로 드세요',
              style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3)),
        ],
      )),
    ]),
  );
}

// ── 섹션 헤더 ────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Text(title, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: AppColors.text, letterSpacing: -0.015)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Row(children: [
            Text(action!, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: -0.01)),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: AppColors.textMuted),
          ]),
        ),
    ]),
  );
}

// ── 끼니 카드 ─────────────────────────────────────
class _MealCard extends StatelessWidget {
  final MealRecord meal;
  final VoidCallback? onMoreTap;
  const _MealCard({required this.meal, this.onMoreTap});

  static Color _chipColor(String label) {
    switch (label) {
      case '아침': return AppColors.breakfast;
      case '점심': return AppColors.lunch;
      case '저녁': return AppColors.dinner;
      default:    return AppColors.snack;
    }
  }

  static Color _chipBg(String label) {
    switch (label) {
      case '아침': return AppColors.breakfastSoft;
      case '점심': return AppColors.lunchSoft;
      case '저녁': return AppColors.dinnerSoft;
      default:    return AppColors.snackSoft;
    }
  }

  static Color _foodBoxColor(String name) {
    const palette = [
      Color(0xFFFCD34D), Color(0xFFF87171), Color(0xFFFB923C),
      Color(0xFF86EFAC), Color(0xFF93C5FD), Color(0xFFC4B5FD),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cc = _chipColor(meal.label);
    final cb = _chipBg(meal.label);
    final totalC = meal.foods.fold(0.0, (s, f) => s + f.carb);
    final totalP = meal.foods.fold(0.0, (s, f) => s + f.protein);
    final totalF = meal.foods.fold(0.0, (s, f) => s + f.fat);
    final macroSum = totalC + totalP + totalF;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        Row(children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cb, borderRadius: BorderRadius.circular(AppRadius.xs)),
            alignment: Alignment.center,
            child: Text(meal.label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: cc)),
          ),
          const SizedBox(width: 8),
          Text(meal.time, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const Spacer(),
          RichText(text: TextSpan(children: [
            TextSpan(text: meal.totalKcal.round().toString(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.text, letterSpacing: -0.02,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const TextSpan(text: 'kcal',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ])),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(Icons.more_horiz_rounded,
                  size: 18, color: AppColors.textMuted),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        ...meal.foods.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _foodBoxColor(f.name),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.text, letterSpacing: -0.01)),
                Text('탄 ${f.carb.round()}g · 단 ${f.protein.round()}g · 지 ${f.fat.round()}g',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            )),
            Text('${f.kcal.round()}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textSub,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        )),

        if (macroSum > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(children: [
              Flexible(flex: totalC.round(), child: Container(height: 4, color: AppColors.carb)),
              Flexible(flex: totalP.round(), child: Container(height: 4, color: AppColors.protein)),
              Flexible(flex: totalF.round(), child: Container(height: 4, color: AppColors.fat)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── 빈 끼니 카드 ─────────────────────────────────
class _EmptyMealCard extends StatelessWidget {
  final String type;
  final int recordedCount;
  final VoidCallback? onRecord;
  const _EmptyMealCard({required this.type, required this.recordedCount, this.onRecord});

  @override
  Widget build(BuildContext context) {
    const total = 3;
    final remaining = total - recordedCount;
    final msg = remaining == 1 ? '$type만 기록하면 오늘 완성!' : '$type 식단을 기록해볼까요?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0A22A447),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand, width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Row(children: List.generate(total, (i) => Container(
            width: 18, height: 4, margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i < recordedCount ? AppColors.brand : AppColors.lineSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ))),
          const SizedBox(width: 8),
          Text('$recordedCount / $total',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.brandText,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: const Color(0x6622A447)),
                  ),
                  alignment: Alignment.center,
                  child: Text(type, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.brandText)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(msg,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.text, letterSpacing: -0.01)),
            ],
          )),
          GestureDetector(
            onTap: onRecord,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x4022A447),
                      blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: Colors.white),
                SizedBox(width: 3),
                Text('기록', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── 식단 상세 바텀시트 ────────────────────────────
class _MealDetailSheet extends StatelessWidget {
  final MealWithFoods meal;
  final VoidCallback onDelete;

  static const _labelColors = {
    '아침': AppColors.breakfast,
    '점심': AppColors.lunch,
    '저녁': AppColors.dinner,
    '기타': AppColors.snack,
  };

  static Color _foodBoxColor(String name) {
    const palette = [
      Color(0xFFFCD34D), Color(0xFFF87171), Color(0xFFFB923C),
      Color(0xFF86EFAC), Color(0xFF93C5FD), Color(0xFFC4B5FD),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  const _MealDetailSheet({required this.meal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final label = meal.meal.label;
    final color = _labelColors[label] ?? AppColors.brand;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lineStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(label, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 10),
              Text(meal.meal.timeDisplay,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
            ]),
            const SizedBox(height: 16),

            const Text('음식 목록',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            ...meal.foods.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _foodBoxColor(f.food.foodName),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.food.foodName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(
                    '탄 ${f.totalCarbG.round()}g  단 ${f.totalProteinG.round()}g  지 ${f.totalFatG.round()}g',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSub),
                  ),
                ])),
                Text('${f.totalKcal.round()}kcal',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              ]),
            )),

            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(children: [
                const Text('총 칼로리',
                    style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                const SizedBox(height: 4),
                Text('${meal.totalKcal.round()} kcal',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                        color: AppColors.brandDark)),
              ]),
            ),
            const SizedBox(height: 10),

            Row(children: [
              _NutrBox(label: '탄수화물', value: '${meal.totalCarbG.round()}g',    color: AppColors.carb),
              const SizedBox(width: 8),
              _NutrBox(label: '단백질',  value: '${meal.totalProteinG.round()}g', color: AppColors.protein),
              const SizedBox(width: 8),
              _NutrBox(label: '지방',    value: '${meal.totalFatG.round()}g',     color: AppColors.fat),
            ]),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => _confirmDelete(context),
              child: Container(
                width: double.infinity, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text('이 식사 기록 삭제',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('식사 기록 삭제'),
        content: const Text('이 식사 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NutrBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NutrBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ── 연속 기록 카드 ────────────────────────────────
class _StreakCard extends StatelessWidget {
  final int todayIndex;
  const _StreakCard({required this.todayIndex});

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 18, color: AppColors.orange),
          const SizedBox(width: 8),
          const Text('연속 기록', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.text, letterSpacing: -0.01)),
          const Spacer(),
          RichText(text: const TextSpan(children: [
            TextSpan(text: '7',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.text, letterSpacing: -0.025)),
            TextSpan(text: '일째',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_days.length, (i) {
            final done  = i <= todayIndex;
            final today = i == todayIndex;
            return Expanded(child: Column(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: today
                      ? AppColors.brand
                      : done
                          ? AppColors.brandSoft
                          : AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: done && !today
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.brand)
                    : today
                        ? Center(child: Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle)))
                        : null,
              ),
              const SizedBox(height: 6),
              Text(_days[i], style: TextStyle(
                  fontSize: 11,
                  fontWeight: today ? FontWeight.w700 : FontWeight.w600,
                  color: today ? AppColors.text : AppColors.textMuted)),
            ]));
          }),
        ),
      ]),
    );
  }
}
