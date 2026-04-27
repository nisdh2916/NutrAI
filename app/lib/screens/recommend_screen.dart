import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recommend_models.dart';
import '../providers/app_state.dart';
import '../services/chat_service.dart';
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

const _kCategories = ['전체', '다이어트', '기호별', '질환맞춤', '건강기능식품'];

class _RecommendScreenState extends State<RecommendScreen> {
  String _selectedCategory = '전체';

  List<RecommendItem> _items = [];
  bool _loading = false;
  String? _error;
  String _coaching = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRecommendations());
  }

  Future<void> _fetchRecommendations({String? category}) async {
    if (_loading) return;
    final cat = category ?? _selectedCategory;
    setState(() { _loading = true; _error = null; });

    try {
      final appState = context.read<AppState>();
      final user = appState.user;
      final todayMeals = appState.todayMeals;
      final mealHistory = todayMeals.isNotEmpty
          ? ChatService.mealsToHistory(todayMeals)
          : null;

      final result = await ChatService.getRecommendations(
        user: user,
        mealHistory: mealHistory,
        count: 5,
        category: cat,
      );

      if (!mounted) return;

      final colors = [
        const Color(0xFFF0E6D3), const Color(0xFFE8DFD0),
        const Color(0xFFF5E8C0), const Color(0xFFE0EDD8),
        const Color(0xFFDDE8F0), const Color(0xFFF5EDE8),
        const Color(0xFFDEF0E4), const Color(0xFFE8EEF5),
      ];

      setState(() {
        _items = result.items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return RecommendItem(
            id: 'r$i',
            name: item.name,
            tags: item.tags,
            description: item.reason,
            placeholderColor: colors[i % colors.length],
            kcal: item.kcal,
            carb: item.carb,
            protein: item.protein,
            fat: item.fat,
            allergenWarning: item.allergenWarning,
            allergenNames: item.allergenNames,
          );
        }).toList();
        _coaching = result.coaching;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
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
          setState(() => _items.remove(item));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('피드백을 반영했어요. 추천을 개선할게요!'),
              backgroundColor: AppColors.brand,
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
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: _loading
            ? const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.brand),
                  SizedBox(height: 16),
                  Text('AI가 맞춤 메뉴를 분석 중이에요...',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ],
              ))
            : _error != null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.lineStrong),
                      const SizedBox(height: 12),
                      const Text('추천을 불러올 수 없어요',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _fetchRecommendations,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.brand),
                        label: const Text('다시 시도',
                            style: TextStyle(color: AppColors.brand)),
                      ),
                    ],
                  ))
                : _RecommendFeed(
                    items: _items,
                    coaching: _coaching,
                    onCardTap: _onCardTap,
                    onFavoriteToggle: (item) => setState(() => item.isFavorite = !item.isFavorite),
                    onFeedbackTap: _showFeedbackSheet,
                    onRefresh: _fetchRecommendations,
                    emptyMessage: '취향 데이터를 더 쌓으면\n맞춤 추천이 정확해져요!',
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
          const Text('추천', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textMuted, letterSpacing: -0.01)),
          const SizedBox(height: 2),
          Row(children: [
            Text('${widget.userName}님을 위한 추천', style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: AppColors.text, letterSpacing: -0.03)),
            const Spacer(),
            GestureDetector(
              onTap: _loading ? null : _fetchRecommendations,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.brandText),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // 카테고리 필터 칩
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final isSel = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    if (!isSel && !_loading) {
                      setState(() => _selectedCategory = cat);
                      _fetchRecommendations(category: cat);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.brand : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: isSel ? null : AppShadows.card,
                    ),
                    alignment: Alignment.center,
                    child: Text(cat, style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Colors.white : AppColors.textSub)),
                  ),
                );
              },
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
// 추천 피드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecommendFeed extends StatelessWidget {
  final List<RecommendItem> items;
  final String coaching;
  final ValueChanged<RecommendItem> onCardTap;
  final ValueChanged<RecommendItem> onFavoriteToggle;
  final ValueChanged<RecommendItem> onFeedbackTap;
  final VoidCallback onRefresh;
  final String emptyMessage;

  const _RecommendFeed({
    required this.items,
    this.coaching = '',
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
            const Icon(Icons.restaurant_menu_outlined, size: 48, color: AppColors.lineStrong),
            const SizedBox(height: 12),
            Text(emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.6)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // AI 가이드 배너
        if (coaching.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22A447), Color(0xFF1E8E3E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(coaching, style: const TextStyle(
                      fontSize: 13, color: Colors.white, height: 1.5,
                      fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RecommendCard(
                  item: items[i],
                  onTap:         () => onCardTap(items[i]),
                  onFavoriteTap: () => onFavoriteToggle(items[i]),
                  onFeedbackTap: () => onFeedbackTap(items[i]),
                ),
              ),
              childCount: items.length,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: GestureDetector(
              onTap: onRefresh,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, size: 14, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('새로고침 — AI가 새로운 메뉴를 추천해요',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 카드
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이미지 영역 ──
            Stack(children: [
              Container(
                height: 140,
                width: double.infinity,
                color: item.placeholderColor,
                child: Center(
                  child: Icon(Icons.restaurant_rounded, size: 48,
                      color: item.placeholderColor.withValues(alpha: 0.35)),
                ),
              ),
              // 하단 그라디언트
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.18)],
                    ),
                  ),
                ),
              ),
              // 알레르기 배지
              if (item.allergenWarning)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 4),
                      Text('알레르기 주의',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              // 즐겨찾기 버튼
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: onFavoriteTap,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16,
                      color: item.isFavorite ? AppColors.red : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ]),

            // ── 카드 본문 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.text, letterSpacing: -0.01)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: item.tags.map((t) => _TagChip(t)).toList()),
                const SizedBox(height: 10),
                Row(children: [
                  _NutrPill('${item.kcal.round()}kcal', AppColors.textSub),
                  const SizedBox(width: 6),
                  _NutrPill('탄 ${item.carb.round()}g', AppColors.carb),
                  const SizedBox(width: 6),
                  _NutrPill('단 ${item.protein.round()}g', AppColors.protein),
                  const Spacer(),
                  GestureDetector(
                    onTap: onFeedbackTap,
                    child: const Icon(Icons.thumb_down_outlined, size: 18, color: AppColors.textMuted),
                  ),
                ]),
              ]),
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
    return Text(text, style: const TextStyle(
        fontSize: 12, color: AppColors.brandText, fontWeight: FontWeight.w500));
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        clipBehavior: Clip.hardEdge,
        child: CustomScrollView(
          controller: ctrl,
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // 이미지
            SliverToBoxAdapter(
              child: Stack(children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  color: item.placeholderColor,
                  child: Center(child: Icon(Icons.restaurant_rounded, size: 72,
                      color: item.placeholderColor.withValues(alpha: 0.4))),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSub),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, right: 54,
                  child: StatefulBuilder(
                    builder: (_, setS) => GestureDetector(
                      onTap: () { onFavoriteToggle(); setS(() {}); },
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: item.isFavorite ? AppColors.red : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, children: item.tags.map((t) => _TagChip(t)).toList()),
                  const SizedBox(height: 8),
                  Text(item.name, style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.03)),
                  const SizedBox(height: 14),

                  // 영양 정보 행
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _NutrStat('칼로리', '${item.kcal.round()}', 'kcal', AppColors.text),
                      Container(width: 1, height: 32, color: AppColors.brandText.withValues(alpha: 0.2)),
                      _NutrStat('탄수화물', '${item.carb.round()}', 'g', AppColors.carb),
                      Container(width: 1, height: 32, color: AppColors.brandText.withValues(alpha: 0.2)),
                      _NutrStat('단백질', '${item.protein.round()}', 'g', AppColors.protein),
                      Container(width: 1, height: 32, color: AppColors.brandText.withValues(alpha: 0.2)),
                      _NutrStat('지방', '${item.fat.round()}', 'g', AppColors.fat),
                    ]),
                  ),

                  // 알레르기 경고
                  if (item.allergenWarning) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_rounded, size: 18, color: AppColors.red),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('알레르기 성분 포함 가능', style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
                          const SizedBox(height: 2),
                          Text('${item.allergenNames.join(', ')} 성분이 포함될 수 있습니다.',
                              style: const TextStyle(fontSize: 12, color: AppColors.red, height: 1.4)),
                        ])),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Text(item.description, style: const TextStyle(
                      fontSize: 14, color: AppColors.textSub, height: 1.65)),
                  const SizedBox(height: 24),

                  // CTA 버튼
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Text('지금 바로 보러가기', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.lineSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Text('다시 내일에도 추천하기', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: onFeedback,
                      child: const Text('추천이 마음에 안 드시나요?', style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted,
                          decoration: TextDecoration.underline)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrStat extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutrStat(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(
          fontSize: 10, color: AppColors.brandText, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        TextSpan(text: unit, style: const TextStyle(
            fontSize: 11, color: AppColors.brandText)),
      ])),
    ]);
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.lineStrong, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          const Text('추천이 마음에 안 드시나요?', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('미선택 사유 선택 (중복가능)', style: TextStyle(
              fontSize: 13, color: AppColors.textSub)),
          const SizedBox(height: 16),

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
                  color: isSel ? AppColors.brandSoft : AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: isSel
                      ? Border.all(color: AppColors.brand, width: 1.5)
                      : null,
                ),
                child: Row(children: [
                  Expanded(child: Text(reason, style: TextStyle(
                      fontSize: 14,
                      color: isSel ? AppColors.brandText : AppColors.text,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400))),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? AppColors.brand : Colors.transparent,
                      border: Border.all(
                          color: isSel ? AppColors.brand : AppColors.textDisabled,
                          width: 1.5),
                    ),
                    child: isSel
                        ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                        : null,
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.lineSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Text('건너뛰기', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => widget.onSubmit(_selected.toList()),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Text('피드백 제출', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
