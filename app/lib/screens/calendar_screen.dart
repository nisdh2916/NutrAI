import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/db_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'food_add_screen.dart';

enum _CalView { week, month }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 기록 화면 (캘린더)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CalendarScreen extends StatefulWidget {
  final VoidCallback? onGoToReport;
  const CalendarScreen({super.key, this.onGoToReport});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _today = DateTime.now();
  DateTime _selected = DateTime.now();
  late DateTime _monthCursor;
  _CalView _view = _CalView.week;
  late TabController _tabCtrl;

  List<MealWithFoods> _meals = [];
  Set<String> _recordedDates = {};

  AppState? _appStateRef;

  @override
  void initState() {
    super.initState();
    _monthCursor = DateTime.now();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      setState(() => _view = _CalView.values[_tabCtrl.index]);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context, listen: false);
    if (_appStateRef != appState) {
      _appStateRef?.removeListener(_onAppStateChanged);
      _appStateRef = appState;
      _appStateRef!.addListener(_onAppStateChanged);
      _loadMeals();
      _loadRecordedDates();
    }
  }

  @override
  void dispose() {
    _appStateRef?.removeListener(_onAppStateChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      _loadMeals();
      _loadRecordedDates();
    }
  }

  Future<void> _loadMeals() async {
    final meals = await _appStateRef?.getMealsForDate(_selected) ?? [];
    if (mounted) setState(() => _meals = meals);
  }

  Future<void> _loadRecordedDates() async {
    final from = DateTime(_monthCursor.year, _monthCursor.month, 1);
    final to   = DateTime(_monthCursor.year, _monthCursor.month + 1, 0);
    final dates = await _appStateRef?.getRecordedDates(from, to) ?? [];
    if (mounted) setState(() => _recordedDates = dates.toSet());
  }

  // ── 날짜 유틸 ────────────────────────────────
  DateTime get _weekStart {
    final wd = _selected.weekday;
    return _selected.subtract(Duration(days: wd - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  List<DateTime?> get _monthGrid {
    final first       = DateTime(_monthCursor.year, _monthCursor.month, 1);
    final startOffset = first.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(_monthCursor.year, _monthCursor.month);
    final cells = <DateTime?>[];
    for (int i = 0; i < startOffset; i++) { cells.add(null); }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_monthCursor.year, _monthCursor.month, d));
    }
    while (cells.length % 7 != 0) { cells.add(null); }
    return cells;
  }

  void _onDayTap(DateTime d) {
    setState(() => _selected = d);
    _loadMeals();
  }

  void _onPrevMonth() {
    setState(() => _monthCursor = DateTime(_monthCursor.year, _monthCursor.month - 1));
    _loadRecordedDates();
  }

  void _onNextMonth() {
    setState(() => _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + 1));
    _loadRecordedDates();
  }

  void _onAddMeal() {
    final hour  = DateTime.now().hour;
    final label = hour < 10 ? '아침' : hour < 15 ? '점심' : '저녁';
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FoodAddScreen(initialMealLabel: label),
      ),
    );
  }

  void _showMealDetail(MealWithFoods meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealDetailSheet(
        meal: meal,
        onDelete: () async {
          await context.read<AppState>().deleteMeal(meal.meal.id!);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildSliverHeader()],
        body: _view == _CalView.week
            ? _WeekBody(
                weekDays:   _weekDays,
                selected:   _selected,
                today:      _today,
                meals:      _meals,
                onDayTap:   _onDayTap,
                onTodayTap: () {
                  setState(() => _selected = _today);
                  _loadMeals();
                },
                onMealTap:  _showMealDetail,
                onAddMeal:  _onAddMeal,
              )
            : _MonthBody(
                monthCursor:   _monthCursor,
                monthGrid:     _monthGrid,
                selected:      _selected,
                today:         _today,
                meals:         _meals,
                recordedDates: _recordedDates,
                onDayTap:      _onDayTap,
                onPrevMonth:   _onPrevMonth,
                onNextMonth:   _onNextMonth,
                onMealTap:     _showMealDetail,
                onGoToReport:  widget.onGoToReport,
                onAddMeal:     _onAddMeal,
              ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader() {
    final wd = ['','월','화','수','목','금','토','일'];
    final d  = _selected;
    return SliverAppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('기록', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted, letterSpacing: -0.01)),
                const SizedBox(height: 2),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                  Text(
                    _view == _CalView.month
                        ? '${_monthCursor.month}월'
                        : '${d.day}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppColors.text, letterSpacing: -0.03),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _view == _CalView.month
                        ? '${_monthCursor.year}'
                        : wd[d.weekday],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.textSub),
                  ),
                  if (_view == _CalView.week) ...[
                    const SizedBox(width: 6),
                    Text('Apr ${d.year}', style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                ]),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() { _selected = _today; _monthCursor = _today; });
                  _loadMeals(); _loadRecordedDates();
                },
                child: Container(
                  height: 32, padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Today', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandText)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // SegmentedControl
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
              tabs: const [Tab(text: '주간'), Tab(text: '월간')],
            ),
          ),
        ]),
      ),
      toolbarHeight: 140,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 주간 뷰 Body
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _WeekBody extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime selected, today;
  final List<MealWithFoods> meals;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onTodayTap;
  final ValueChanged<MealWithFoods> onMealTap;
  final VoidCallback onAddMeal;

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  const _WeekBody({
    required this.weekDays, required this.selected, required this.today,
    required this.meals, required this.onDayTap, required this.onTodayTap,
    required this.onMealTap, required this.onAddMeal,
  });

  bool _isSame(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── 주간 날짜 스트립 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.surface,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: weekDays.asMap().entries.map((e) {
                final i       = e.key;
                final d       = e.value;
                final isSel   = _isSame(d, selected);
                final isToday = _isSame(d, today);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(d),
                    child: Column(children: [
                      Text(_wd[i], style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: isSel ? AppColors.brand : AppColors.textMuted,
                          letterSpacing: -0.01)),
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
          ),
        ),

        // ── 당일 통계 3칸 ──
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              _StatMini(label: '총 섭취', value: '0', unit: 'kcal'),
              SizedBox(width: 8),
              _StatMini(label: '끼니 수', value: '0', unit: '/ 3'),
              SizedBox(width: 8),
              _StatMini(label: '달성률', value: '0', unit: '%', valueColor: AppColors.brandText),
            ]),
          ),
        ),

        // ── 끼니 타임라인 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: meals.isEmpty
              ? SliverToBoxAdapter(child: _EmptyDay(onAddMeal: onAddMeal))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TimelineMealRow(
                      meal:   meals[i],
                      isLast: i == meals.length - 1,
                      onTap:  () => onMealTap(meals[i]),
                    ),
                    childCount: meals.length,
                  ),
                ),
        ),
      ],
    );
  }

}

// ── 통계 미니 카드 ───────────────────────────────
class _StatMini extends StatelessWidget {
  final String label, value, unit;
  final Color? valueColor;
  const _StatMini({required this.label, required this.value,
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
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
          Text(value, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.text,
              letterSpacing: -0.02,
              fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 2),
          Text(unit, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ]),
      ]),
    ),
  );
}

// ── 끼니 라벨 칩 ──────────────────────────────────
class _MealChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MealChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    alignment: Alignment.center,
    child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 월간 뷰 Body
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MonthBody extends StatelessWidget {
  final DateTime monthCursor, selected, today;
  final List<DateTime?> monthGrid;
  final List<MealWithFoods> meals;
  final Set<String> recordedDates;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrevMonth, onNextMonth;
  final ValueChanged<MealWithFoods> onMealTap;
  final VoidCallback? onGoToReport;
  final VoidCallback onAddMeal;

  static const _wd      = ['월', '화', '수', '목', '금', '토', '일'];
  static const _monthKr = ['','1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'];

  const _MonthBody({
    required this.monthCursor, required this.monthGrid, required this.selected,
    required this.today, required this.meals, required this.recordedDates,
    required this.onDayTap, required this.onPrevMonth, required this.onNextMonth,
    required this.onMealTap, required this.onAddMeal, this.onGoToReport,
  });

  bool _isSame(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasData(DateTime? d) {
    if (d == null) return false;
    final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    return recordedDates.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── 월 이동 헤더 ──
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
                ),
                Text(
                  '${_monthKr[monthCursor.month]}  ${monthCursor.year}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSub),
                ),
              ],
            ),
          ),
        ),

        // ── 요일 헤더 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: _wd.map((w) => Expanded(
                child: Center(
                  child: Text(w, style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ),
        ),

        // ── 날짜 그리드 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
                mainAxisSpacing: 4,
              ),
              itemCount: monthGrid.length,
              itemBuilder: (ctx, i) {
                final d       = monthGrid[i];
                if (d == null) return const SizedBox();
                final isSel   = _isSame(d, selected);
                final isToday = _isSame(d, today);
                final hasDot  = _hasData(d);
                return GestureDetector(
                  onTap: () => onDayTap(d),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? AppColors.brand : Colors.transparent,
                          border: isToday && !isSel
                              ? Border.all(color: AppColors.brand, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white
                                  : isToday ? AppColors.brand
                                  : d.month != monthCursor.month ? AppColors.textDisabled
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasDot
                              ? (isSel ? Colors.white70 : AppColors.brand)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        SliverToBoxAdapter(child: Container(height: 1, color: AppColors.line)),

        // ── 선택 날짜 식단 요약 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverToBoxAdapter(
            child: meals.isEmpty
                ? _EmptyDay(onAddMeal: onAddMeal)
                : _DaySummarySection(
                    selected:    selected,
                    meals:       meals,
                    onMealTap:   onMealTap,
                    onGoToReport: onGoToReport,
                  ),
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 타임라인 끼니 행 (주간 뷰용)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TimelineMealRow extends StatelessWidget {
  final MealWithFoods meal;
  final bool isLast;
  final VoidCallback onTap;

  static const _labelColors = {
    '아침': AppColors.breakfast,
    '점심': AppColors.lunch,
    '저녁': AppColors.dinner,
    '간식': Color(0xFF8B5CF6),
  };

  const _TimelineMealRow({required this.meal, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color    = _labelColors[meal.meal.label] ?? AppColors.brand;
    final timeParts = meal.meal.timeDisplay.split(' ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 시간 ──
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeParts[0],
                    style: const TextStyle(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w500)),
                Text(timeParts.length > 1 ? timeParts[1] : '',
                    style: const TextStyle(fontSize: 10, color: AppColors.textDisabled)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── 타임라인 점 + 선 ──
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: AppColors.lineStrong)),
            ],
          ),
          const SizedBox(width: 12),

          // ── 오른쪽: 끼니 카드 ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: _TimelineMealCard(meal: meal, color: color, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMealCard extends StatelessWidget {
  final MealWithFoods meal;
  final Color color;
  final VoidCallback onTap;
  const _TimelineMealCard({required this.meal, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _MealChip(label: meal.meal.label, color: color),
              const Spacer(),
              Text('${meal.totalKcal.round()}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.text, letterSpacing: -0.02,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Text('kcal', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              const Icon(Icons.more_horiz_rounded, size: 16, color: AppColors.textMuted),
            ]),
            const SizedBox(height: 12),

            // 음식 목록
            ...meal.foods.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Expanded(child: Text(f.food.foodName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: AppColors.text, letterSpacing: -0.01))),
                Text('${f.totalKcal.round()}kcal',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
              ]),
            )),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                _MiniStat(label: '탄', value: '${meal.totalCarbG.round()}g',    color: AppColors.carb),
                const SizedBox(width: 10),
                _MiniStat(label: '단', value: '${meal.totalProteinG.round()}g', color: AppColors.protein),
                const SizedBox(width: 10),
                _MiniStat(label: '지', value: '${meal.totalFatG.round()}g',     color: AppColors.fat),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9,  color: AppColors.textSub)),
          Text(value,  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      ),
    ]);
  }
}

// ── 월간 뷰 선택일 요약 ────────────────────────────
class _DaySummarySection extends StatelessWidget {
  final DateTime selected;
  final List<MealWithFoods> meals;
  final ValueChanged<MealWithFoods> onMealTap;
  final VoidCallback? onGoToReport;

  static const _wd      = ['','월','화','수','목','금','토','일'];
  static const _colors  = {
    '아침': AppColors.breakfast,
    '점심': AppColors.lunch,
    '저녁': AppColors.dinner,
    '간식': Color(0xFF8B5CF6),
  };

  const _DaySummarySection({
    required this.selected, required this.meals,
    required this.onMealTap, this.onGoToReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selected.month}/${selected.day} (${_wd[selected.weekday]}) 식단',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        const SizedBox(height: 12),

        ...meals.map((m) {
          final color = _colors[m.meal.label] ?? AppColors.brand;
          return GestureDetector(
            onTap: () => onMealTap(m),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Row(children: [
                _MealChip(label: m.meal.label, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.summary,
                      style: const TextStyle(fontSize: 13, color: AppColors.text,
                          fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${m.totalKcal.round()}kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSub,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),

        // 리포트 이동 버튼
        GestureDetector(
          onTap: onGoToReport,
          child: Container(
            width: double.infinity, height: 46,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.brandText),
              SizedBox(width: 6),
              Text('식단으로 리포트 보러가기',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.brandText)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 기록 없는 날 ──────────────────────────────────
class _EmptyDay extends StatelessWidget {
  final VoidCallback? onAddMeal;
  const _EmptyDay({this.onAddMeal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu_rounded, size: 44, color: AppColors.lineStrong),
          const SizedBox(height: 12),
          const Text('아직 기록된 식단이 없어요',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAddMeal,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              alignment: Alignment.center,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 16, color: AppColors.brandText),
                SizedBox(width: 4),
                Text('식단 추가하러 가기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.brandText)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 식사 상세 바텀시트
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MealDetailSheet extends StatelessWidget {
  final MealWithFoods meal;
  final VoidCallback onDelete;

  static const _labelColors = {
    '아침': AppColors.breakfast,
    '점심': AppColors.lunch,
    '저녁': AppColors.dinner,
    '간식': Color(0xFF8B5CF6),
  };

  const _MealDetailSheet({required this.meal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final label     = meal.meal.label;
    final color     = _labelColors[label] ?? AppColors.brand;
    final photoPath = meal.meal.photoPath;

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
            // 드래그 핸들
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lineStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // 끼니 라벨 + 시간
            Row(children: [
              _MealChip(label: label, color: color),
              const SizedBox(width: 10),
              Text(meal.meal.timeDisplay,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
            ]),
            const SizedBox(height: 16),

            // ── 사진 섹션 ──
            if (photoPath != null && photoPath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(photoPath),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
                ),
              )
            else
              const _PhotoPlaceholder(),
            const SizedBox(height: 16),

            // ── 음식 목록 ──
            const Text('음식 목록',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            ...meal.foods.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Center(child: Icon(Icons.restaurant_rounded, size: 16, color: AppColors.brand)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.food.foodName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(
                      '탄 ${f.totalCarbG.round()}g  단 ${f.totalProteinG.round()}g  지 ${f.totalFatG.round()}g',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSub),
                    ),
                  ]),
                ),
                Text('${f.totalKcal.round()}kcal',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              ]),
            )),

            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 14),

            // ── 칼로리 강조 박스 ──
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
              ]),
            ),
            const SizedBox(height: 10),

            // ── 탄/단/지 ──
            Row(children: [
              _NutrBox(label: '탄수화물', value: '${meal.totalCarbG.round()}g',    color: AppColors.carb),
              const SizedBox(width: 8),
              _NutrBox(label: '단백질',  value: '${meal.totalProteinG.round()}g', color: AppColors.protein),
              const SizedBox(width: 8),
              _NutrBox(label: '지방',    value: '${meal.totalFatG.round()}g',     color: AppColors.fat),
            ]),
            const SizedBox(height: 20),

            // ── 삭제 버튼 ──
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

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_not_supported_outlined, size: 28, color: AppColors.lineStrong),
        SizedBox(height: 6),
        Text('등록된 사진이 없습니다', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
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
        Text(value,  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
