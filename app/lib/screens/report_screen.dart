import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/db_models.dart';
import '../models/meal_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

// 공용 헬퍼
MealRecord _toRecord(MealWithFoods mwf) => MealRecord(
      label: mwf.meal.label,
      time: mwf.meal.timeDisplay,
      foods: mwf.foods
          .map((f) => MealFood(
                name: f.food.foodName,
                kcal: f.totalKcal,
                carb: f.totalCarbG,
                protein: f.totalProteinG,
                fat: f.totalFatG,
              ))
          .toList(),
    );

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget _buildLoading() => const Center(
      child: CircularProgressIndicator(color: AppColors.green400),
    );

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 리포트 화면 (루트)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ReportScreen extends StatefulWidget {
  final String userName;
  const ReportScreen({super.key, this.userName = '00'});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _DailyTab(
                selected: _selected,
                onDateChanged: (d) => setState(() => _selected = d)),
            _WeeklyTab(
                selected: _selected,
                onDateChanged: (d) => setState(() => _selected = d)),
            _MonthlyTab(
                selected: _selected,
                onDateChanged: (d) => setState(() => _selected = d)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('리포트', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textMuted, letterSpacing: -0.01)),
          const SizedBox(height: 2),
          Text('${widget.userName}님의 건강 리포트', style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: AppColors.text, letterSpacing: -0.03)),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.lineSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.text,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  letterSpacing: -0.01),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicator: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 2)],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '일간'), Tab(text: '주간'), Tab(text: '월간')],
            ),
          ),
        ]),
      ),
      toolbarHeight: 130,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공용 날짜 스트립
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  const _WeekStrip({required this.selected, required this.onTap});

  List<DateTime> get _days {
    final offset = selected.weekday - 1;
    final mon = selected.subtract(Duration(days: offset));
    return List.generate(7, (i) => mon.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: _days.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final isSel = _sameDay(d, selected);
          final isToday = _sameDay(d, today);
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(d),
              child: Column(children: [
                Text(_wd[i], style: TextStyle(
                    fontSize: 11,
                    color: isSel ? AppColors.brand : AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel ? AppColors.brand : Colors.transparent,
                    border: isToday && !isSel
                        ? Border.all(color: AppColors.brand, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('${d.day}', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white
                          : isToday ? AppColors.brand
                          : AppColors.text,
                      letterSpacing: -0.02)),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 일간 리포트 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _DailyTab extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;

  const _DailyTab({required this.selected, required this.onDateChanged});

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  List<MealWithFoods>? _data;

  static const _weekdayKr = ['', '월', '화', '수', '목', '금', '토', '일'];
  static const _monthKr = [
    '', '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월'
  ];

  @override
  void initState() {
    super.initState();
    _load(widget.selected);
  }

  @override
  void didUpdateWidget(_DailyTab old) {
    super.didUpdateWidget(old);
    if (!_sameDay(old.selected, widget.selected)) _load(widget.selected);
  }

  Future<void> _load(DateTime date) async {
    final data = await context.read<AppState>().getMealsForDate(date);
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return _buildLoading();

    final meals = _data!.map(_toRecord).toList();
    final totalK = meals.fold(0.0, (s, m) => s + m.totalKcal);
    final totalC = meals.fold(0.0, (s, m) => s + m.totalCarb);
    final totalP = meals.fold(0.0, (s, m) => s + m.totalProtein);
    final totalF = meals.fold(0.0, (s, m) => s + m.totalFat);
    final sel = widget.selected;
    final dateStr =
        '${sel.year}년 ${_monthKr[sel.month]} ${sel.day}일 ${_weekdayKr[sel.weekday]}요일';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _WeekStrip(
                selected: widget.selected, onTap: widget.onDateChanged)),
        SliverToBoxAdapter(
            child: Divider(height: 0.5, color: AppColors.border)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            Text(dateStr, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: -0.01)),
            const SizedBox(height: 14),

            _MealThumbnailRow(meals: meals),
            const SizedBox(height: 14),

            _NutritionCard(
              totalKcal: totalK,
              carb: totalC,
              protein: totalP,
              fat: totalF,
            ),
            const SizedBox(height: 14),

            if (meals.isNotEmpty) _TipCard(meals: meals, totalKcal: totalK),
            if (meals.isEmpty) _EmptyReport(),
          ])),
        ),
      ],
    );
  }
}

// ── 끼니 썸네일 행 ─────────────────────────────────
class _MealThumbnailRow extends StatelessWidget {
  final List<MealRecord> meals;
  const _MealThumbnailRow({required this.meals});

  static const _labels  = ['아침', '점심', '저녁'];
  static const _times   = ['08:30', '12:30', '19:00'];
  static const _colors  = [AppColors.breakfast, AppColors.lunch, AppColors.dinner];
  static const _softBgs = [AppColors.breakfastSoft, AppColors.lunchSoft, AppColors.dinnerSoft];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final meal = meals.where((m) => m.label == _labels[i]).firstOrNull;
        final color = _colors[i];
        final soft  = _softBgs[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: meal != null ? soft : AppColors.lineSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Icon(
                      meal != null ? Icons.restaurant_rounded : Icons.add_rounded,
                      size: 18,
                      color: meal != null ? color : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_labels[i], style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: meal != null ? color : AppColors.textMuted)),
                Text(meal != null ? _times[i] : '—',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                if (meal != null) ...[
                  const SizedBox(height: 4),
                  Text('${meal.totalKcal.round()}kcal',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.textSub)),
                ],
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── 영양소 도넛 카드 ───────────────────────────────
class _NutritionCard extends StatelessWidget {
  final double totalKcal, carb, protein, fat;
  const _NutritionCard({
    required this.totalKcal,
    required this.carb,
    required this.protein,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final total = carb + protein + fat;
    final cPct = total > 0 ? (carb / total * 100).round() : 0;
    final pPct = total > 0 ? (protein / total * 100).round() : 0;
    final fPct = total > 0 ? (fat / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('영양소 분석', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.text, letterSpacing: -0.01)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 120, height: 120,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _DonutPainter(carb: carb, protein: protein, fat: fat),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${totalKcal.round()}', style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.text, letterSpacing: -0.03,
                    fontFeatures: [FontFeature.tabularFigures()])),
                const Text('kcal', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NutrRow(label: '탄수화물', gram: carb, pct: cPct, color: AppColors.carb),
                const SizedBox(height: 14),
                _NutrRow(label: '단백질',  gram: protein, pct: pPct, color: AppColors.protein),
                const SizedBox(height: 14),
                _NutrRow(label: '지방',    gram: fat,     pct: fPct, color: AppColors.fat),
              ],
            ),
          ),
        ]),
      ]),
    );
  }
}

class _NutrRow extends StatelessWidget {
  final String label;
  final double gram;
  final int pct;
  final Color color;
  const _NutrRow({required this.label, required this.gram,
      required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$pct%  ${gram.round()}g', style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 5,
          backgroundColor: AppColors.lineSoft,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ── AI 코치 조언 카드 ──────────────────────────────
class _TipCard extends StatelessWidget {
  final List<MealRecord> meals;
  final double totalKcal;
  const _TipCard({required this.meals, required this.totalKcal});

  String get _tip {
    final totalP = meals.fold(0.0, (s, m) => s + m.totalProtein);
    final totalC = meals.fold(0.0, (s, m) => s + m.totalCarb);
    final totalF = meals.fold(0.0, (s, m) => s + m.totalFat);
    if (totalP < 50)   return '오늘 단백질 섭취가 부족해요. 닭가슴살, 두부, 계란 등 단백질이 풍부한 음식을 추가해보세요.';
    if (totalC > 300)  return '탄수화물 섭취가 다소 높아요. 다음 끼니에는 채소 위주의 식단을 선택해보세요.';
    if (totalF > 80)   return '지방 섭취가 목표치를 초과했어요. 튀긴 음식보다 구운 음식을 선택하면 도움이 돼요.';
    if (totalKcal < 1200) return '오늘 칼로리 섭취가 너무 적어요. 균형 잡힌 식사로 기초대사량을 유지해주세요.';
    return '오늘 식단이 전반적으로 균형 잡혀 있어요! 다른 날도 이렇게 유지해보세요.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F4EA), Color(0xFFF0FAF2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.tips_and_updates_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text('AI 코치', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brandText)),
        ]),
        const SizedBox(height: 10),
        Text(_tip, style: const TextStyle(
            fontSize: 13, color: AppColors.brandText, height: 1.6,
            fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── 도넛 CustomPainter ─────────────────────────────
class _DonutPainter extends CustomPainter {
  final double carb, protein, fat;
  const _DonutPainter({required this.carb, required this.protein, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = carb + protein + fat;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;

    p.color = AppColors.lineSoft;
    canvas.drawCircle(Offset(cx, cy), r, p);

    if (total == 0) return;

    const gap = 0.04;
    final segs = [
      (carb / total, AppColors.carb),
      (protein / total, AppColors.protein),
      (fat / total, AppColors.fat),
    ];
    double start = -math.pi / 2;
    for (final (ratio, color) in segs) {
      final sweep = ratio * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      p.color = color;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start, sweep, false, p);
      start += ratio * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.carb != carb || o.protein != protein || o.fat != fat;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 주간 리포트 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _WeeklyTab extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;
  const _WeeklyTab({required this.selected, required this.onDateChanged});

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  Map<String, double>? _kcalMap;
  List<List<MealRecord>>? _weekMeals;

  DateTime get _monday {
    final s = widget.selected;
    return s.subtract(Duration(days: s.weekday - 1));
  }

  bool _sameWeek(DateTime a, DateTime b) {
    final ma = a.subtract(Duration(days: a.weekday - 1));
    final mb = b.subtract(Duration(days: b.weekday - 1));
    return _sameDay(ma, mb);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_WeeklyTab old) {
    super.didUpdateWidget(old);
    if (!_sameWeek(old.selected, widget.selected)) _load();
  }

  Future<void> _load() async {
    final mon = _monday;
    final appState = context.read<AppState>();
    final kcalMap = await appState.getWeeklyKcal(mon);
    final days = List.generate(7, (i) => mon.add(Duration(days: i)));
    final mealsList =
        await Future.wait(days.map((d) => appState.getMealsForDate(d)));
    if (mounted) {
      setState(() {
        _kcalMap = kcalMap;
        _weekMeals =
            mealsList.map((l) => l.map(_toRecord).toList()).toList();
      });
    }
  }

  List<DateTime> get _weekDays => List.generate(
      7, (i) => _monday.add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    if (_kcalMap == null || _weekMeals == null) {
      return Column(children: [
        _WeekStrip(selected: widget.selected, onTap: widget.onDateChanged),
        Divider(height: 0.5, color: AppColors.border),
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.green400))),
      ]);
    }

    final days = _weekDays;
    final data = days.map((d) => _kcalMap![_dateKey(d)] ?? 0.0).toList();
    final maxK = data.isEmpty ? 1.0 : data.reduce(math.max).clamp(1.0, double.infinity);
    final avgK = data.fold(0.0, (s, v) => s + v) / 7;
    final totalK = data.fold(0.0, (s, v) => s + v);
    const wd = ['월', '화', '수', '목', '금', '토', '일'];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: _WeekStrip(selected: widget.selected, onTap: widget.onDateChanged)),
      SliverToBoxAdapter(child: Divider(height: 0.5, color: AppColors.border)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        sliver: SliverList(
            delegate: SliverChildListDelegate([
          Row(children: [
            _StatCard(label: '주간 총 칼로리', value: '${totalK.round()}', unit: 'kcal'),
            const SizedBox(width: 10),
            _StatCard(label: '일 평균', value: '${avgK.round()}', unit: 'kcal'),
            const SizedBox(width: 10),
            _StatCard(
                label: '기록된 날',
                value: '${data.where((v) => v > 0).length}',
                unit: '/ 7일',
                valueColor: AppColors.brandText),
          ]),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('일별 칼로리', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.text, letterSpacing: -0.01)),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final isSel = _sameDay(days[i], widget.selected);
                    final ratio = data[i] / maxK;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (data[i] > 0)
                              Text('${data[i].round()}', style: TextStyle(
                                  fontSize: 9,
                                  color: isSel ? AppColors.brandText : AppColors.textMuted)),
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: () => widget.onDateChanged(days[i]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: ratio * 110,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.brand
                                      : data[i] > 0
                                          ? AppColors.brandSoft
                                          : AppColors.lineSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(wd[i], style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? AppColors.brand : AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('이번 주 식단 요약', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.text, letterSpacing: -0.01)),
              const SizedBox(height: 12),
              ...List.generate(7, (i) {
                final meals = _weekMeals![i];
                final isSel = _sameDay(days[i], widget.selected);
                if (meals.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.brandSoft : AppColors.bgAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(children: [
                    Text(wd[i], style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isSel ? AppColors.brandText : AppColors.textSub)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        meals.map((m) => '${m.label}: ${m.summary}').join('  '),
                        style: TextStyle(
                            fontSize: 11,
                            color: isSel ? AppColors.brandText : AppColors.textSub),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                        '${meals.fold(0.0, (s, m) => s + m.totalKcal).round()}kcal',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: isSel ? AppColors.brandText : AppColors.text)),
                  ]),
                );
              }),
              if (_weekMeals!.every((ml) => ml.isEmpty)) _EmptyReport(),
            ]),
          ),
        ])),
      ),
    ]);
  }
}

// ── 통계 카드 (주간/월간 공용) ─────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final Color? valueColor;
  const _StatCard({required this.label, required this.value,
      required this.unit, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.text,
              letterSpacing: -0.02,
              fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 2),
          Text(unit, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ]),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 월간 리포트 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MonthlyTab extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;
  const _MonthlyTab({required this.selected, required this.onDateChanged});

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  late DateTime _cursor;
  Map<String, double>? _monthKcalMap;
  List<MealWithFoods>? _selMeals;

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.selected.year, widget.selected.month);
    _loadMonth(_cursor);
    _loadDay(widget.selected);
  }

  @override
  void didUpdateWidget(_MonthlyTab old) {
    super.didUpdateWidget(old);
    if (!_sameDay(old.selected, widget.selected)) _loadDay(widget.selected);
  }

  Future<void> _loadMonth(DateTime cursor) async {
    final map = await context.read<AppState>().getMonthlyKcal(cursor.year, cursor.month);
    if (mounted && _cursor.year == cursor.year && _cursor.month == cursor.month) {
      setState(() => _monthKcalMap = map);
    }
  }

  Future<void> _loadDay(DateTime date) async {
    final meals = await context.read<AppState>().getMealsForDate(date);
    if (mounted) setState(() => _selMeals = meals);
  }

  void _goMonth(int delta) {
    final next = DateTime(_cursor.year, _cursor.month + delta);
    setState(() {
      _cursor = next;
      _monthKcalMap = null;
    });
    _loadMonth(next);
  }

  List<DateTime?> get _grid {
    final first  = DateTime(_cursor.year, _cursor.month, 1);
    final offset = first.weekday - 1;
    final days   = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final cells  = <DateTime?>[
      ...List.filled(offset, null),
      ...List.generate(days, (i) => DateTime(_cursor.year, _cursor.month, i + 1)),
    ];
    while (cells.length % 7 != 0) cells.add(null);
    return cells;
  }

  static const _monthKr = [
    '', '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월'
  ];
  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final selMeals = (_selMeals ?? []).map(_toRecord).toList();

    final monthTotal = _monthKcalMap == null
        ? 0.0
        : _monthKcalMap!.values.fold(0.0, (s, v) => s + v);
    final activeDays = _monthKcalMap == null
        ? 0
        : _monthKcalMap!.values.where((v) => v > 0).length;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
              onPressed: () => _goMonth(-1),
            ),
            Text('${_monthKr[_cursor.month]}  ${_cursor.year}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSub),
              onPressed: () => _goMonth(1),
            ),
          ]),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: _wd.map((w) => Expanded(
              child: Center(child: Text(w, style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
            )).toList(),
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _monthKcalMap == null
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: AppColors.green400)))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.85,
                      mainAxisSpacing: 4),
                  itemCount: _grid.length,
                  itemBuilder: (ctx, i) {
                    final d = _grid[i];
                    if (d == null) return const SizedBox();
                    final isSel   = _sameDay(d, widget.selected);
                    final isToday = _sameDay(d, today);
                    final hasDot  = (_monthKcalMap![_dateKey(d)] ?? 0) > 0;
                    return GestureDetector(
                      onTap: () {
                        widget.onDateChanged(d);
                        _loadDay(d);
                      },
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? AppColors.brand : Colors.transparent,
                            border: isToday && !isSel
                                ? Border.all(color: AppColors.brand, width: 1.5)
                                : null,
                          ),
                          child: Center(child: Text('${d.day}', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white
                                  : isToday ? AppColors.brand
                                  : d.month != _cursor.month ? AppColors.textDisabled
                                  : AppColors.text))),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasDot
                                ? (isSel ? Colors.white70 : AppColors.brand)
                                : Colors.transparent,
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ),

      SliverToBoxAdapter(child: Container(height: 1, color: AppColors.line)),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        sliver: SliverList(
            delegate: SliverChildListDelegate([
          Row(children: [
            _StatCard(label: '월 총 칼로리', value: '${monthTotal.round()}', unit: 'kcal'),
            const SizedBox(width: 10),
            _StatCard(label: '기록한 날', value: '$activeDays', unit: '일'),
            const SizedBox(width: 10),
            _StatCard(
                label: '일 평균',
                value: activeDays > 0 ? '${(monthTotal / activeDays).round()}' : '0',
                unit: 'kcal',
                valueColor: AppColors.brandText),
          ]),
          const SizedBox(height: 14),

          if (_selMeals == null)
            const Center(child: CircularProgressIndicator(color: AppColors.green400)),

          if (_selMeals != null && selMeals.isNotEmpty) ...[
            Text(
              '${widget.selected.month}/${widget.selected.day} 식단',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.text, letterSpacing: -0.01),
            ),
            const SizedBox(height: 10),
            ...selMeals.map((m) {
              const colors = {
                '아침': AppColors.breakfast,
                '점심': AppColors.lunch,
                '저녁': AppColors.dinner,
              };
              final color = colors[m.label] ?? AppColors.brand;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: Row(children: [
                  Container(
                    height: 26, padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.label, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.summary,
                      style: const TextStyle(fontSize: 13, color: AppColors.text,
                          fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${m.totalKcal.round()}kcal',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSub,
                          fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],

          if (_selMeals != null && selMeals.isEmpty) _EmptyReport(),
        ])),
      ),
    ]);
  }
}

// ── 빈 리포트 상태 ─────────────────────────────────
class _EmptyReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.insert_chart_outlined_rounded,
            size: 48, color: AppColors.lineStrong),
        SizedBox(height: 12),
        Text('아직 식단 기록이 없어요',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text('+ 버튼으로 오늘 식사를 기록해보세요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}
