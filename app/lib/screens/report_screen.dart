import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/db_models.dart';
import '../models/meal_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

// 영양소 색상 상수
const _kCarb = Color(0xFF5BA4D0);
const _kProtein = Color(0xFF639922);
const _kFat = Color(0xFFE8A838);

// ── 공용 헬퍼 ───────────────────────────────────────
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
      backgroundColor: AppColors.background,
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
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        '${widget.userName}님의 건강 리포트',
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Column(children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.green600,
            unselectedLabelColor: AppColors.gray400,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorColor: AppColors.green400,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: '일간 리포트'),
              Tab(text: '주간 리포트'),
              Tab(text: '월간 리포트')
            ],
          ),
          Divider(height: 0.5, color: AppColors.border),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공용 날짜 스트립 위젯
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
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                Text(_wd[i],
                    style: TextStyle(
                        fontSize: 11,
                        color: isSel ? AppColors.green400 : AppColors.gray400,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 5),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel ? AppColors.green400 : Colors.transparent,
                    border: isToday && !isSel
                        ? Border.all(color: AppColors.green400, width: 1.5)
                        : null,
                  ),
                  child: Center(
                      child: Text('${d.day}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Colors.white
                                  : isToday
                                      ? AppColors.green400
                                      : AppColors.textPrimary))),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            Text(dateStr,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
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

  static const _labels = ['아침', '점심', '저녁'];
  static const _times = ['08:30', '12:30', '19:00'];
  static const _colors = [_kCarb, _kProtein, _kFat];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final meal = meals.where((m) => m.label == _labels[i]).firstOrNull;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: Column(children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: meal != null
                      ? _colors[i].withValues(alpha: 0.15)
                      : AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: meal != null
                          ? _colors[i].withValues(alpha: 0.3)
                          : AppColors.border,
                      width: 0.5),
                ),
                child: Center(
                  child: Icon(
                    meal != null ? Icons.restaurant_rounded : Icons.add_rounded,
                    size: 28,
                    color: meal != null ? _colors[i] : AppColors.gray200,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(_labels[i],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: meal != null ? _colors[i] : AppColors.gray200)),
              Text(meal != null ? _times[i] : '—',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.gray200)),
            ]),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _DonutPainter(carb: carb, protein: protein, fat: fat),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${totalKcal.round()}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Text('kcal',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NutrRow(label: '탄수화물', gram: carb, pct: cPct, color: _kCarb),
                const SizedBox(height: 12),
                _NutrRow(
                    label: '단백질', gram: protein, pct: pPct, color: _kProtein),
                const SizedBox(height: 12),
                _NutrRow(label: '지방', gram: fat, pct: fPct, color: _kFat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrRow extends StatelessWidget {
  final String label;
  final double gram;
  final int pct;
  final Color color;
  const _NutrRow(
      {required this.label,
      required this.gram,
      required this.pct,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Text('$pct%  ${gram.round()}g',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 5,
          backgroundColor: AppColors.gray50,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ── 맞춤 조언 카드 ─────────────────────────────────
class _TipCard extends StatelessWidget {
  final List<MealRecord> meals;
  final double totalKcal;
  const _TipCard({required this.meals, required this.totalKcal});

  String get _tip {
    final totalP = meals.fold(0.0, (s, m) => s + m.totalProtein);
    final totalC = meals.fold(0.0, (s, m) => s + m.totalCarb);
    final totalF = meals.fold(0.0, (s, m) => s + m.totalFat);
    if (totalP < 50)
      return '오늘 단백질 섭취가 부족해요. 닭가슴살, 두부, 계란 등 단백질이 풍부한 음식을 추가해보세요.';
    if (totalC > 300) return '탄수화물 섭취가 다소 높아요. 다음 끼니에는 채소 위주의 식단을 선택해보세요.';
    if (totalF > 80) return '지방 섭취가 목표치를 초과했어요. 튀긴 음식보다 구운 음식을 선택하면 도움이 돼요.';
    if (totalKcal < 1200) return '오늘 칼로리 섭취가 너무 적어요. 균형 잡힌 식사로 기초대사량을 유지해주세요.';
    return '오늘 식단이 전반적으로 균형 잡혀 있어요! 다른 날도 이렇게 유지해보세요 🎉';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green100, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tips_and_updates_rounded,
              size: 16, color: AppColors.green600),
          const SizedBox(width: 6),
          const Text('맞춤 조언',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green800)),
        ]),
        const SizedBox(height: 8),
        Text(_tip,
            style: const TextStyle(
                fontSize: 13, color: AppColors.green600, height: 1.6)),
      ]),
    );
  }
}

// ── 도넛 CustomPainter ─────────────────────────────
class _DonutPainter extends CustomPainter {
  final double carb, protein, fat;
  const _DonutPainter(
      {required this.carb, required this.protein, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = carb + protein + fat;
    if (total == 0) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = AppColors.gray50;
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width / 2 - 8, p);
      return;
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    p.color = AppColors.gray50;
    canvas.drawCircle(Offset(cx, cy), r, p);

    const gap = 0.04;
    final segs = [
      (carb / total, _kCarb),
      (protein / total, _kProtein),
      (fat / total, _kFat)
    ];
    double start = -math.pi / 2;
    for (final (ratio, color) in segs) {
      final sweep = ratio * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      p.color = color;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
          sweep, false, p);
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
    const _wd = ['월', '화', '수', '목', '금', '토', '일'];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: _WeekStrip(selected: widget.selected, onTap: widget.onDateChanged)),
      SliverToBoxAdapter(child: Divider(height: 0.5, color: AppColors.border)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        sliver: SliverList(
            delegate: SliverChildListDelegate([
          // 주간 요약 수치 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(children: [
              _StatBox(
                  label: '주간 총 칼로리', value: '${totalK.round()}', unit: 'kcal'),
              Container(width: 0.5, height: 44, color: AppColors.border),
              _StatBox(
                  label: '일 평균 칼로리', value: '${avgK.round()}', unit: 'kcal'),
              Container(width: 0.5, height: 44, color: AppColors.border),
              _StatBox(
                  label: '기록된 날',
                  value: '${data.where((v) => v > 0).length}',
                  unit: '/ 7일'),
            ]),
          ),
          const SizedBox(height: 14),

          // 막대 차트 카드
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('일별 칼로리',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
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
                              Text('${data[i].round()}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: isSel
                                          ? AppColors.green600
                                          : AppColors.gray200)),
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: () => widget.onDateChanged(days[i]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: ratio * 110,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.green400
                                      : data[i] > 0
                                          ? AppColors.green100
                                          : AppColors.gray50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_wd[i],
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isSel
                                        ? AppColors.green400
                                        : AppColors.gray400)),
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

          // 요일별 끼니 요약
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('이번 주 식단 요약',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...List.generate(7, (i) {
                final meals = _weekMeals![i];
                final isSel = _sameDay(days[i], widget.selected);
                if (meals.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.green50 : AppColors.gray50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSel ? AppColors.green100 : AppColors.border,
                        width: 0.5),
                  ),
                  child: Row(children: [
                    Text(_wd[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel
                                ? AppColors.green600
                                : AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        meals.map((m) => '${m.label}: ${m.summary}').join('  '),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                        '${meals.fold(0.0, (s, m) => s + m.totalKcal).round()}kcal',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
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

class _StatBox extends StatelessWidget {
  final String label, value, unit;
  const _StatBox(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        RichText(
            text: TextSpan(children: [
          TextSpan(
              text: value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          TextSpan(
              text: ' $unit',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }
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
    final first = DateTime(_cursor.year, _cursor.month, 1);
    final offset = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final cells = <DateTime?>[
      ...List.filled(offset, null),
      ...List.generate(
          days, (i) => DateTime(_cursor.year, _cursor.month, i + 1)),
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
      // 월 이동 헤더
      SliverToBoxAdapter(
        child: Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => _goMonth(-1),
            ),
            Text('${_monthKr[_cursor.month]}  ${_cursor.year}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => _goMonth(1),
            ),
          ]),
        ),
      ),

      // 요일 헤더
      SliverToBoxAdapter(
        child: Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
              children: _wd
                  .map((w) => Expanded(
                      child: Center(
                          child: Text(w,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gray400,
                                  fontWeight: FontWeight.w500)))))
                  .toList()),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 6)),

      // 캘린더 그리드
      SliverToBoxAdapter(
        child: Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _monthKcalMap == null
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.green400)))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: 4),
                  itemCount: _grid.length,
                  itemBuilder: (ctx, i) {
                    final d = _grid[i];
                    if (d == null) return const SizedBox();
                    final isSel = _sameDay(d, widget.selected);
                    final isToday = _sameDay(d, today);
                    final hasDot = (_monthKcalMap![_dateKey(d)] ?? 0) > 0;
                    return GestureDetector(
                      onTap: () {
                        widget.onDateChanged(d);
                        _loadDay(d);
                      },
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel
                                    ? AppColors.green400
                                    : Colors.transparent,
                                border: isToday && !isSel
                                    ? Border.all(
                                        color: AppColors.green400, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                  child: Text('${d.day}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSel
                                              ? Colors.white
                                              : isToday
                                                  ? AppColors.green400
                                                  : d.month != _cursor.month
                                                      ? AppColors.gray200
                                                      : AppColors.textPrimary))),
                            ),
                            const SizedBox(height: 2),
                            Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasDot
                                        ? (isSel
                                            ? Colors.white70
                                            : AppColors.green400)
                                        : Colors.transparent)),
                          ]),
                    );
                  },
                ),
        ),
      ),

      SliverToBoxAdapter(child: Divider(height: 0.5, color: AppColors.border)),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        sliver: SliverList(
            delegate: SliverChildListDelegate([
          // 월간 통계 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(children: [
              _StatBox(
                  label: '월 총 칼로리',
                  value: '${monthTotal.round()}',
                  unit: 'kcal'),
              Container(width: 0.5, height: 44, color: AppColors.border),
              _StatBox(label: '기록한 날', value: '$activeDays', unit: '일'),
              Container(width: 0.5, height: 44, color: AppColors.border),
              _StatBox(
                  label: '일 평균',
                  value: activeDays > 0
                      ? '${(monthTotal / activeDays).round()}'
                      : '0',
                  unit: 'kcal'),
            ]),
          ),
          const SizedBox(height: 14),

          // 선택 날짜 식단 요약
          if (_selMeals == null)
            const Center(child: CircularProgressIndicator(color: AppColors.green400)),

          if (_selMeals != null && selMeals.isNotEmpty) ...[
            Text(
              '${widget.selected.month}/${widget.selected.day} 식단',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            ...selMeals.map((m) {
              final colors = {'아침': _kCarb, '점심': _kProtein, '저녁': _kFat};
              final color = colors[m.label] ?? _kProtein;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(m.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(m.summary,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary))),
                  Text('${m.totalKcal.round()}kcal',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.insert_chart_outlined_rounded,
            size: 48, color: AppColors.gray100),
        const SizedBox(height: 12),
        const Text('아직 식단 기록이 없어요',
            style: TextStyle(fontSize: 14, color: AppColors.gray400)),
        const SizedBox(height: 4),
        const Text('+ 버튼으로 오늘 식사를 기록해보세요',
            style: TextStyle(fontSize: 12, color: AppColors.gray200)),
      ]),
    );
  }
}
