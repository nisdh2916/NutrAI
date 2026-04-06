import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_theme.dart';

// ── 주간/월간 뷰 enum ────────────────────────────
enum _CalView { week, month }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 기록 화면 (캘린더)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _today      = DateTime.now();
  DateTime _selected   = DateTime.now();
  DateTime _monthCursor; // 월간 뷰에서 보여줄 월
  _CalView _view       = _CalView.week;
  late TabController _tabCtrl;

  _CalendarScreenState() : _monthCursor = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      setState(() => _view = _CalView.values[_tabCtrl.index]);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── 날짜 유틸 ────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, _today);

  DateTime get _weekStart {
    final wd = _selected.weekday; // 1=월 ~ 7=일
    return _selected.subtract(Duration(days: wd - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  List<MealRecord> get _selectedMeals => MealSampleData.forDate(_selected);

  // ── 헤더 날짜 문자열 ─────────────────────────
  static const _weekdayKr = ['월', '화', '수', '목', '금', '토', '일'];
  static const _monthEn   = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  String get _headerDate {
    final wd = _weekdayKr[_selected.weekday - 1];
    final mo = _monthEn[_selected.month];
    return '${_selected.day}  $wd  $mo ${_selected.year}';
  }

  // ── 월간 캘린더 날짜 그리드 ──────────────────
  List<DateTime?> get _monthGrid {
    final first = DateTime(_monthCursor.year, _monthCursor.month, 1);
    final startOffset = first.weekday - 1; // 0=월 기준
    final daysInMonth = DateUtils.getDaysInMonth(_monthCursor.year, _monthCursor.month);
    final cells = <DateTime?>[];
    for (int i = 0; i < startOffset; i++) cells.add(null);
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_monthCursor.year, _monthCursor.month, d));
    }
    // 6행 맞추기
    while (cells.length % 7 != 0) cells.add(null);
    return cells;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildSliverHeader()],
        body: _view == _CalView.week ? _WeekBody(
          weekDays:      _weekDays,
          selected:      _selected,
          today:         _today,
          meals:         _selectedMeals,
          onDayTap:      (d) => setState(() => _selected = d),
          headerDate:    _headerDate,
          onTodayTap:    () => setState(() { _selected = _today; }),
        ) : _MonthBody(
          monthCursor:   _monthCursor,
          monthGrid:     _monthGrid,
          selected:      _selected,
          today:         _today,
          meals:         _selectedMeals,
          onDayTap:      (d) => setState(() => _selected = d),
          onPrevMonth:   () => setState(() => _monthCursor = DateTime(_monthCursor.year, _monthCursor.month - 1)),
          onNextMonth:   () => setState(() => _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + 1)),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader() {
    return SliverAppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.green600,
        unselectedLabelColor: AppColors.gray400,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        indicatorColor: AppColors.green400,
        indicatorWeight: 2,
        tabs: const [Tab(text: '주간'), Tab(text: '월간')],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(height: 0.5, color: AppColors.border),
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
  final List<MealRecord> meals;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onTodayTap;
  final String headerDate;

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];

  const _WeekBody({
    required this.weekDays, required this.selected, required this.today,
    required this.meals, required this.onDayTap, required this.onTodayTap,
    required this.headerDate,
  });

  bool _isSame(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── 날짜 헤더 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  selected.day.toString(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_wd[selected.weekday - 1]}  ${_monthEn(selected.month)} ${selected.year}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onTodayTap,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.green50,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 12, color: AppColors.green600, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),

        // ── 주간 날짜 스트립 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Row(
              children: weekDays.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                final isSel   = _isSame(d, selected);
                final isToday = _isSame(d, today);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(d),
                    child: Column(
                      children: [
                        Text(
                          _wd[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel ? AppColors.green400 : AppColors.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? AppColors.green400 : Colors.transparent,
                            border: isToday && !isSel
                                ? Border.all(color: AppColors.green400, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white
                                    : isToday ? AppColors.green400
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── 구분선 ──
        SliverToBoxAdapter(child: Divider(height: 0.5, color: AppColors.border)),

        // ── 끼니 타임라인 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: meals.isEmpty
              ? SliverToBoxAdapter(child: _EmptyDay())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TimelineMealRow(meal: meals[i], isLast: i == meals.length - 1),
                    childCount: meals.length,
                  ),
                ),
        ),
      ],
    );
  }

  static String _monthEn(int m) =>
      const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 월간 뷰 Body
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MonthBody extends StatelessWidget {
  final DateTime monthCursor, selected, today;
  final List<DateTime?> monthGrid;
  final List<MealRecord> meals;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrevMonth, onNextMonth;

  static const _wd = ['월', '화', '수', '목', '금', '토', '일'];
  static const _monthKr = ['','1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'];

  const _MonthBody({
    required this.monthCursor, required this.monthGrid, required this.selected,
    required this.today, required this.meals, required this.onDayTap,
    required this.onPrevMonth, required this.onNextMonth,
  });

  bool _isSame(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasData(DateTime? d) =>
      d != null && MealSampleData.forDate(d).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── 월 이동 헤더 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                ),
                Text(
                  '${_monthKr[monthCursor.month]}  ${monthCursor.year}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // ── 요일 헤더 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _wd.map((w) => Expanded(
                child: Center(
                  child: Text(w, style: const TextStyle(fontSize: 11, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── 날짜 그리드 ──
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
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
                final d = monthGrid[i];
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
                          color: isSel ? AppColors.green400 : Colors.transparent,
                          border: isToday && !isSel
                              ? Border.all(color: AppColors.green400, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSel ? Colors.white
                                  : isToday ? AppColors.green400
                                  : d.month != monthCursor.month ? AppColors.gray200
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // 식단 기록 있는 날 점 표시
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasDot
                              ? (isSel ? Colors.white70 : AppColors.green400)
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

        SliverToBoxAdapter(child: Divider(height: 0.5, color: AppColors.border)),

        // ── 선택 날짜 식단 요약 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverToBoxAdapter(
            child: meals.isEmpty
                ? _EmptyDay()
                : _DaySummarySection(selected: selected, meals: meals),
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
  final MealRecord meal;
  final bool isLast;
  const _TimelineMealRow({required this.meal, required this.isLast});

  static const _labelColors = {
    '아침': Color(0xFF5BA4D0),
    '점심': Color(0xFF639922),
    '저녁': Color(0xFFE8A838),
  };

  @override
  Widget build(BuildContext context) {
    final color = _labelColors[meal.label] ?? AppColors.green400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 시간 + 타임라인 선 ──
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  meal.time.split(' ').first, // "08:30"
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  meal.time.split(' ').last, // "AM"
                  style: const TextStyle(fontSize: 10, color: AppColors.gray200),
                ),
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
                Expanded(
                  child: Container(width: 1.5, color: AppColors.gray100),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ── 오른쪽: 끼니 카드 ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: _TimelineMealCard(meal: meal, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMealCard extends StatelessWidget {
  final MealRecord meal;
  final Color color;
  const _TimelineMealCard({required this.meal, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(meal.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.gray200),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 음식 목록
          ...meal.foods.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ),
                Text('${f.kcal.round()}kcal', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          )),

          const SizedBox(height: 6),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // 합계
          Row(
            children: [
              _MiniStat(label: '탄수화물', value: '${meal.totalCarb.round()}g', color: const Color(0xFF5BA4D0)),
              const SizedBox(width: 12),
              _MiniStat(label: '단백질', value: '${meal.totalProtein.round()}g', color: AppColors.green400),
              const SizedBox(width: 12),
              _MiniStat(label: '칼로리', value: '${meal.totalKcal.round()}kcal', color: const Color(0xFFE8A838)),
            ],
          ),
        ],
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
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          Text(value,  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    ]);
  }
}

// ── 월간 뷰 선택일 요약 ────────────────────────────
class _DaySummarySection extends StatelessWidget {
  final DateTime selected;
  final List<MealRecord> meals;
  const _DaySummarySection({required this.selected, required this.meals});

  static const _wd = ['','월','화','수','목','금','토','일'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selected.month}/${selected.day} (${_wd[selected.weekday]}) 식단',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),

        // 끼니별 한 줄 요약
        ...meals.map((m) {
          final colors = {'아침': const Color(0xFF5BA4D0), '점심': AppColors.green400, '저녁': const Color(0xFFE8A838)};
          final color  = colors[m.label] ?? AppColors.green400;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(m.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(m.summary, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ),
              Text('${m.totalKcal.round()}kcal', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          );
        }),

        const SizedBox(height: 16),

        // 리포트 보러 가기 버튼
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.green400),
          label: const Text('식단으로 리포트 보러가기', style: TextStyle(fontSize: 13, color: AppColors.green400)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: AppColors.green400, width: 1.5),
          ),
        ),
      ],
    );
  }
}

// ── 기록 없는 날 ──────────────────────────────────
class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 44, color: AppColors.gray100),
          const SizedBox(height: 12),
          const Text('아직 기록된 식단이 없어요', style: TextStyle(fontSize: 14, color: AppColors.gray400)),
          const SizedBox(height: 6),
          const Text('+ 버튼으로 식사를 추가해보세요', style: TextStyle(fontSize: 12, color: AppColors.gray200)),
        ],
      ),
    );
  }
}
