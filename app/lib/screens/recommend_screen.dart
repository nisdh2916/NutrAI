import 'package:flutter/material.dart';
import '../models/recommend_models.dart';
import '../theme/app_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 화면 (루트)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class RecommendScreen extends StatefulWidget {
  final String userName;
  const RecommendScreen({super.key, this.userName = '00'});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  late List<RecommendItem> _preference;
  late List<RecommendItem> _today;

  @override
  void initState() {
    super.initState();
    _tabCtrl   = TabController(length: 2, vsync: this);
    _preference = List.from(RecommendSampleData.preference);
    _today      = List.from(RecommendSampleData.today);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      // 새로고침: 순서를 섞어 새 추천처럼 보이게 (실제론 API 호출)
      _preference = [..._preference.reversed];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('새로운 추천을 불러왔어요!'),
        backgroundColor: AppColors.green400,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onCardTap(RecommendItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecommendDetailSheet(
        item: item,
        userName: widget.userName,
        onFeedback: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _showFeedbackSheet(item);
          });
        },
        onFavoriteToggle: () => setState(() => item.isFavorite = !item.isFavorite),
      ),
    );
  }

  void _showFeedbackSheet(RecommendItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackSheet(
        itemName: item.name,
        onSubmit: (reasons) {
          Navigator.pop(context);
          setState(() => _preference.remove(item));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('피드백을 반영했어요. 추천을 개선할게요!'),
              backgroundColor: AppColors.green400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
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
            _RecommendFeed(
              items: _preference,
              onCardTap: _onCardTap,
              onFavoriteToggle: (item) => setState(() => item.isFavorite = !item.isFavorite),
              onFeedbackTap: _showFeedbackSheet,
              onRefresh: _refresh,
              emptyMessage: '취향 데이터를 더 쌓으면\n맞춤 추천이 정확해져요!',
            ),
            _RecommendFeed(
              items: _today,
              onCardTap: _onCardTap,
              onFavoriteToggle: (item) => setState(() => item.isFavorite = !item.isFavorite),
              onFeedbackTap: _showFeedbackSheet,
              onRefresh: _refresh,
              emptyMessage: '오늘 식단 기록이 없어\n맞춤 추천을 준비 중이에요.',
            ),
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
        '${widget.userName}님을 위한 추천',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.green400),
          tooltip: '새로고침',
          onPressed: _refresh,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.green600,
              unselectedLabelColor: AppColors.gray400,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              indicatorColor: AppColors.green400,
              indicatorWeight: 2,
              tabs: const [Tab(text: '사용자 취향 식단'), Tab(text: '오늘 맞춤 식단')],
            ),
            Divider(height: 0.5, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 피드 (탭 공용)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecommendFeed extends StatelessWidget {
  final List<RecommendItem> items;
  final ValueChanged<RecommendItem> onCardTap;
  final ValueChanged<RecommendItem> onFavoriteToggle;
  final ValueChanged<RecommendItem> onFeedbackTap;
  final VoidCallback onRefresh;
  final String emptyMessage;

  const _RecommendFeed({
    required this.items,
    required this.onCardTap,
    required this.onFavoriteToggle,
    required this.onFeedbackTap,
    required this.onRefresh,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 48, color: AppColors.gray100),
            const SizedBox(height: 12),
            Text(emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.gray400, height: 1.6)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RecommendCard(
                  item: items[i],
                  onTap:           () => onCardTap(items[i]),
                  onFavoriteTap:   () => onFavoriteToggle(items[i]),
                  onFeedbackTap:   () => onFeedbackTap(items[i]),
                ),
              ),
              childCount: items.length,
            ),
          ),
        ),

        // 하단 새로고침 힌트
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.gray400),
              label: const Text(
                '새로고침 가능 — 새로운 추천',
                style: TextStyle(fontSize: 12, color: AppColors.gray400),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 카드 (피드 목록용)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecommendCard extends StatelessWidget {
  final RecommendItem item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onFeedbackTap;

  const _RecommendCard({
    required this.item,
    required this.onTap,
    required this.onFavoriteTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 음식 이미지 영역 ──
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: item.placeholderColor,
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 52,
                      color: item.placeholderColor.withOpacity(0.4),
                    ),
                  ),
                ),
                // 즐겨찾기 버튼
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: item.isFavorite ? Colors.red : AppColors.gray400,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── 카드 본문 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 음식 이름
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),

                  // 해시태그
                  Wrap(
                    spacing: 6,
                    children: item.tags.map((t) => _TagChip(t)).toList(),
                  ),
                  const SizedBox(height: 10),

                  // 영양 요약 + 피드백 버튼
                  Row(
                    children: [
                      _NutrPill('${item.kcal.round()}kcal', AppColors.textSecondary),
                      const SizedBox(width: 6),
                      _NutrPill('탄 ${item.carb.round()}g', const Color(0xFF5BA4D0)),
                      const SizedBox(width: 6),
                      _NutrPill('단 ${item.protein.round()}g', AppColors.green400),
                      const Spacer(),
                      GestureDetector(
                        onTap: onFeedbackTap,
                        child: const Icon(Icons.thumb_down_outlined, size: 18, color: AppColors.gray200),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.green600, fontWeight: FontWeight.w500),
    );
  }
}

class _NutrPill extends StatelessWidget {
  final String label;
  final Color color;
  const _NutrPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 상세 바텀시트
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecommendDetailSheet extends StatelessWidget {
  final RecommendItem item;
  final String userName;
  final VoidCallback onFeedback;
  final VoidCallback onFavoriteToggle;

  const _RecommendDetailSheet({
    required this.item,
    required this.userName,
    required this.onFeedback,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.93,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.hardEdge,
        child: CustomScrollView(
          controller: ctrl,
          slivers: [
            // ── 드래그 핸들 ──
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── 큰 이미지 ──
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Container(
                    height: 240,
                    width: double.infinity,
                    color: item.placeholderColor,
                    child: Center(
                      child: Icon(Icons.restaurant_rounded, size: 80,
                          color: item.placeholderColor.withOpacity(0.5)),
                    ),
                  ),
                  // 닫기 버튼
                  Positioned(
                    top: 12, right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  // 즐겨찾기
                  Positioned(
                    top: 12, right: 54,
                    child: StatefulBuilder(
                      builder: (_, setS) => GestureDetector(
                        onTap: () { onFavoriteToggle(); setS(() {}); },
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: item.isFavorite ? Colors.red : AppColors.gray400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 본문 ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 태그
                    Wrap(
                      spacing: 8,
                      children: item.tags.map((t) => _TagChip(t)).toList(),
                    ),
                    const SizedBox(height: 10),

                    // 이름
                    Text(item.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),

                    // 영양 정보 행
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.green50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NutrStat('칼로리', '${item.kcal.round()}', 'kcal', AppColors.textPrimary),
                          _vDivider(),
                          _NutrStat('탄수화물', '${item.carb.round()}', 'g', const Color(0xFF5BA4D0)),
                          _vDivider(),
                          _NutrStat('단백질', '${item.protein.round()}', 'g', AppColors.green600),
                          _vDivider(),
                          _NutrStat('지방', '${item.fat.round()}', 'g', const Color(0xFFE8A838)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 설명
                    Text(item.description,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.65)),
                    const SizedBox(height: 28),

                    // 액션 버튼 2개
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green400,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('지금 바로 보러가기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('다시 내일에도 추천하기', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 14),

                    // 피드백 링크
                    Center(
                      child: TextButton(
                        onPressed: onFeedback,
                        child: const Text(
                          '추천이 마음에 안 드시나요?',
                          style: TextStyle(fontSize: 13, color: AppColors.gray400, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(width: 0.5, height: 32, color: AppColors.green100);
}

class _NutrStat extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutrStat(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.green600)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              TextSpan(text: unit,  style: const TextStyle(fontSize: 11, color: AppColors.green600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 피드백 바텀시트
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _FeedbackSheet extends StatefulWidget {
  final String itemName;
  final void Function(List<String>) onSubmit;
  const _FeedbackSheet({required this.itemName, required this.onSubmit});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          const Text(
            '추천이 마음에 안 드시나요?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            '미선택 사유 선택 (중복가능)',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // 사유 목록
          ...feedbackReasons.map((reason) {
            final isSel = _selected.contains(reason);
            return GestureDetector(
              onTap: () => setState(() {
                isSel ? _selected.remove(reason) : _selected.add(reason);
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.green50 : AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AppColors.green400 : AppColors.border,
                    width: isSel ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSel ? AppColors.green800 : AppColors.textPrimary,
                          fontWeight: isSel ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? AppColors.green400 : Colors.transparent,
                        border: Border.all(
                          color: isSel ? AppColors.green400 : AppColors.gray200,
                          width: 1.5,
                        ),
                      ),
                      child: isSel
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // 버튼 행
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('건너뛰기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onSubmit(_selected.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green400,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('피드백 제출', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
