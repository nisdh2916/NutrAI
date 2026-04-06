import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/meal_models.dart';
import '../models/db_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 음식 DB
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _FoodDB {
  static const all = [
    MealFood(name: '깍두기',       carb: 8,  protein: 1,  fat: 0,  kcal: 38),
    MealFood(name: '무말랭이',     carb: 20, protein: 2,  fat: 0,  kcal: 92),
    MealFood(name: '도라지무침',   carb: 10, protein: 2,  fat: 1,  kcal: 56),
    MealFood(name: '전미채',       carb: 14, protein: 8,  fat: 1,  kcal: 98),
    MealFood(name: '오징어채볶음', carb: 12, protein: 14, fat: 3,  kcal: 132),
    MealFood(name: '라면',         carb: 70, protein: 9,  fat: 14, kcal: 450),
    MealFood(name: '비빔밥',       carb: 65, protein: 18, fat: 8,  kcal: 410),
    MealFood(name: '된장찌개',     carb: 12, protein: 8,  fat: 4,  kcal: 115),
    MealFood(name: '삼겹살',       carb: 5,  protein: 28, fat: 32, kcal: 430),
    MealFood(name: '김치찌개',     carb: 15, protein: 12, fat: 8,  kcal: 180),
    MealFood(name: '공기밥',       carb: 70, protein: 5,  fat: 1,  kcal: 310),
    MealFood(name: '제육볶음',     carb: 20, protein: 25, fat: 14, kcal: 310),
    MealFood(name: '순두부찌개',   carb: 10, protein: 10, fat: 5,  kcal: 130),
    MealFood(name: '불고기',       carb: 15, protein: 26, fat: 10, kcal: 260),
    MealFood(name: '잡채',         carb: 40, protein: 8,  fat: 6,  kcal: 248),
    MealFood(name: '김밥',         carb: 48, protein: 12, fat: 6,  kcal: 300),
    MealFood(name: '떡볶이',       carb: 60, protein: 6,  fat: 4,  kcal: 300),
    MealFood(name: '닭가슴살',     carb: 0,  protein: 31, fat: 3,  kcal: 165),
    MealFood(name: '두부조림',     carb: 8,  protein: 10, fat: 5,  kcal: 120),
    MealFood(name: '시금치나물',   carb: 4,  protein: 3,  fat: 1,  kcal: 38),
  ];

  // AI 분석 시뮬레이션 (실제론 YOLO 결과)
  static const aiDetected = [
    MealFood(name: '비빔밥',   carb: 65, protein: 18, fat: 8,  kcal: 410),
    MealFood(name: '된장찌개', carb: 12, protein: 8,  fat: 4,  kcal: 115),
    MealFood(name: '제육볶음', carb: 20, protein: 25, fat: 14, kcal: 310),
  ];

  // 특정 음식 대안 제안 (실제론 confidence 낮은 후보군)
  static const alternatives = [
    MealFood(name: '깍두기',     carb: 8,  protein: 1,  fat: 0,  kcal: 38),
    MealFood(name: '무말랭이',   carb: 20, protein: 2,  fat: 0,  kcal: 92),
    MealFood(name: '도라지무침', carb: 10, protein: 2,  fat: 1,  kcal: 56),
    MealFood(name: '전미채',     carb: 14, protein: 8,  fat: 1,  kcal: 98),
    MealFood(name: '오징어채볶음',carb:12, protein: 14, fat: 3,  kcal: 132),
    MealFood(name: '라면',       carb: 70, protein: 9,  fat: 14, kcal: 450),
  ];

  static List<MealFood> search(String q) {
    if (q.trim().isEmpty) return [];
    return all.where((f) => f.name.contains(q.trim())).toList();
  }
}

Color _foodColor(String name) {
  final c = [
    const Color(0xFFE8D5C4), const Color(0xFFD4E8C4), const Color(0xFFC4D4E8),
    const Color(0xFFE8C4D4), const Color(0xFFE8E8C4), const Color(0xFFC4E8E8),
  ];
  return c[name.hashCode.abs() % c.length];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 화면 상태
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum _ScreenState {
  initial,   // 초기: 카메라/갤러리 버튼
  analyzing, // 분석 중 로딩
  confirmed, // AI 분석 결과 표시 (확인 대기)
  editing,   // 특정 항목 수정 중
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 음식 추가 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FoodAddScreen extends StatefulWidget {
  final String initialMealLabel;
  const FoodAddScreen({super.key, this.initialMealLabel = '아침'});

  @override
  State<FoodAddScreen> createState() => _FoodAddScreenState();
}

class _FoodAddScreenState extends State<FoodAddScreen> {
  late String _mealLabel;
  _ScreenState _state = _ScreenState.initial;

  // AI 분석 결과 목록 (수정 가능)
  final List<MealFood> _detectedFoods = [];

  // 현재 수정 중인 항목 인덱스 (-1 = 없음)
  int _editingIndex = -1;

  // 검색
  final TextEditingController _searchCtrl = TextEditingController();
  List<MealFood> _searchResults = [];

  static const _mealLabels = ['아침', '점심', '저녁'];
  static const _mealColors = [Color(0xFF5BA4D0), Color(0xFF639922), Color(0xFFE8A838)];

  @override
  void initState() {
    super.initState();
    _mealLabel = widget.initialMealLabel;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── DB 검색 ──
  void _onSearch() async {
    final q = _searchCtrl.text;
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final appState = context.read<AppState>();
    final results  = await appState.searchFoods(q);
    // FoodEntity → MealFood 변환
    setState(() {
      _searchResults = results.map((f) => MealFood(
        name: f.foodName, carb: f.carbG,
        protein: f.proteinG, fat: f.fatG, kcal: f.kcal,
      )).toList();
    });
  }

  // ── 사진 촬영/갤러리 ──
  Future<void> _onPhoto() async {
    HapticFeedback.lightImpact();
    setState(() => _state = _ScreenState.analyzing);
    // AI 분석 시뮬레이션 (실제론 YOLO 서버 호출)
    await Future.delayed(const Duration(milliseconds: 1400));
    setState(() {
      _detectedFoods
        ..clear()
        ..addAll(_FoodDB.aiDetected);
      _state = _ScreenState.confirmed;
    });
  }

  // ── 수정 버튼 탭 ──
  void _onEditTap(int index) {
    setState(() {
      if (_editingIndex == index) {
        // 같은 항목 다시 누르면 닫기
        _editingIndex = -1;
        _state = _ScreenState.confirmed;
        _searchCtrl.clear();
        _searchResults = [];
      } else {
        _editingIndex = index;
        _state = _ScreenState.editing;
        _searchCtrl.clear();
        _searchResults = [];
      }
    });
  }

  // ── 대안 음식 선택 ──
  void _onSelectAlternative(MealFood food) {
    if (_editingIndex < 0) return;
    setState(() {
      _detectedFoods[_editingIndex] = food;
      _editingIndex = -1;
      _state = _ScreenState.confirmed;
      _searchCtrl.clear();
      _searchResults = [];
    });
    HapticFeedback.selectionClick();
  }

  // ── 항목 삭제 ──
  void _onRemoveFood(int index) {
    setState(() {
      _detectedFoods.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = -1;
        _state = _ScreenState.confirmed;
      } else if (_editingIndex > index) {
        _editingIndex--;
      }
      if (_detectedFoods.isEmpty) {
        _state = _ScreenState.initial;
        _editingIndex = -1;
      }
    });
  }

  // ── DB 저장 ──
  void _onSave() async {
    if (_detectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가할 음식을 선택해주세요'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final appState = context.read<AppState>();

    // FoodEntity id 조회 (name으로 매핑)
    final allFoods = await appState.getAllFoods();
    final foodIdMap = {for (final f in allFoods) f.foodName: f.id};

    final foodArgs = <({int foodId, double? amountG, double servingCount})>[];
    for (final f in _detectedFoods) {
      final fid = foodIdMap[f.name];
      if (fid != null) {
        foodArgs.add((foodId: fid, amountG: null, servingCount: 1.0));
      }
    }

    if (foodArgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음식 정보를 찾을 수 없어요. 검색 후 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await appState.saveMeal(
      mealType: MealEntity.typeFromLabel(_mealLabel),
      eatenAt:  DateTime.now(),
      foods:    foodArgs,
    );

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  double get _totalKcal =>
      _detectedFoods.fold(0.0, (s, f) => s + f.kcal);

  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [

            // 끼니 선택
            SliverToBoxAdapter(child: _MealSelector(
              selected:  _mealLabel,
              labels:    _mealLabels,
              colors:    _mealColors,
              onChanged: (v) => setState(() => _mealLabel = v),
            )),

            // ── 초기 상태: 카메라/갤러리 ──
            if (_state == _ScreenState.initial) ...[
              SliverToBoxAdapter(child: _PhotoButtons(onPhoto: _onPhoto)),
              SliverToBoxAdapter(child: _SearchBarWidget(
                controller: _searchCtrl,
                hintText: '사용자 직접 검색',
              )),
              if (_searchResults.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _SearchResultTile(
                      food: _searchResults[i],
                      onTap: () {
                        setState(() {
                          _detectedFoods.add(_searchResults[i]);
                          _state = _ScreenState.confirmed;
                          _searchCtrl.clear();
                          _searchResults = [];
                        });
                      },
                    ),
                    childCount: _searchResults.length,
                  )),
                ),
            ],

            // ── 분석 중 ──
            if (_state == _ScreenState.analyzing)
              SliverToBoxAdapter(child: _AnalyzingWidget()),

            // ── AI 결과 + 수정 ──
            if (_state == _ScreenState.confirmed ||
                _state == _ScreenState.editing) ...[

              // 사진 완료 배너 (작게)
              SliverToBoxAdapter(child: _PhotoDoneBanner(
                onRetake: () => setState(() {
                  _state = _ScreenState.initial;
                  _detectedFoods.clear();
                  _editingIndex = -1;
                }),
              )),

              // AI 분석 결과 헤더
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.green600),
                        const SizedBox(width: 4),
                        const Text('AI 분석 결과',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.green600)),
                      ]),
                    ),
                    const Spacer(),
                    Text('총 ${_totalKcal.round()}kcal',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),

              // 탐지된 음식 리스트
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DetectedFoodRow(
                    food:       _detectedFoods[i],
                    isEditing:  _editingIndex == i,
                    onEdit:     () => _onEditTap(i),
                    onRemove:   () => _onRemoveFood(i),
                  ),
                  childCount: _detectedFoods.length,
                )),
              ),

              // ── 수정 패널 (편집 중인 경우) ──
              if (_state == _ScreenState.editing) ...[
                SliverToBoxAdapter(child: _EditPanel(
                  searchCtrl:    _searchCtrl,
                  searchResults: _searchResults,
                  onSelectAlt:   _onSelectAlternative,
                )),
              ],

              // 음식 직접 추가 버튼 (+ 더하기)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _editingIndex = _detectedFoods.length; // 새 항목 추가 모드
                      _state = _ScreenState.editing;
                      _detectedFoods.add(const MealFood(
                          name: '(새 음식)', carb: 0, protein: 0, fat: 0, kcal: 0));
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.green400),
                        SizedBox(width: 6),
                        Text('음식 직접 추가', style: TextStyle(
                            fontSize: 13, color: AppColors.green400, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ]),
        ),

        // ── 하단 저장 버튼 ──
        _BottomSaveBar(
          state:      _state,
          foodCount:  _detectedFoods.length,
          totalKcal:  _totalKcal,
          mealLabel:  _mealLabel,
          onSave:     _onSave,
        ),
      ]),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: AppColors.white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('음식 추가',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    centerTitle: true,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0.5),
      child: Divider(height: 0.5, color: AppColors.border),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 끼니 선택
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MealSelector extends StatelessWidget {
  final String selected;
  final List<String> labels;
  final List<Color> colors;
  final ValueChanged<String> onChanged;
  const _MealSelector({required this.selected, required this.labels,
      required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        const Text('끼니', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(width: 16),
        ...List.generate(labels.length, (i) {
          final isSel = selected == labels[i];
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(labels[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? colors[i] : AppColors.gray50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSel ? colors[i] : AppColors.border,
                      width: isSel ? 0 : 0.5),
                ),
                child: Text(labels[i], style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 사진 촬영/갤러리 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PhotoButtons extends StatelessWidget {
  final VoidCallback onPhoto;
  const _PhotoButtons({required this.onPhoto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        Expanded(child: _PhotoBtn(
          icon: Icons.camera_alt_rounded, label: 'AI 카메라로 촬영',
          sub: '사진으로 자동 인식', color: AppColors.green400, onTap: onPhoto)),
        const SizedBox(width: 10),
        Expanded(child: _PhotoBtn(
          icon: Icons.photo_library_rounded, label: '갤러리에서 선택',
          sub: '저장된 사진 불러오기', color: const Color(0xFF5BA4D0), onTap: onPhoto)),
      ]),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _PhotoBtn({required this.icon, required this.label,
      required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 분석 중 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _AnalyzingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green100),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.green400),
        ),
        SizedBox(height: 12),
        Text('AI가 음식을 분석하고 있어요...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green600)),
        SizedBox(height: 4),
        Text('잠시만 기다려주세요',
            style: TextStyle(fontSize: 11, color: AppColors.green400)),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 사진 완료 배너 (작게)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PhotoDoneBanner extends StatelessWidget {
  final VoidCallback onRetake;
  const _PhotoDoneBanner({required this.onRetake});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green100),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.green400),
        const SizedBox(width: 8),
        const Expanded(child: Text('사진 분석 완료!',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green600))),
        GestureDetector(
          onTap: onRetake,
          child: const Row(children: [
            Icon(Icons.refresh_rounded, size: 15, color: AppColors.green400),
            SizedBox(width: 3),
            Text('다시 촬영', style: TextStyle(fontSize: 11, color: AppColors.green400)),
          ]),
        ),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 탐지된 음식 한 행
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _DetectedFoodRow extends StatelessWidget {
  final MealFood food;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _DetectedFoodRow({
    required this.food, required this.isEditing,
    required this.onEdit, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isEditing ? AppColors.green50 : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? AppColors.green400 : AppColors.border,
          width: isEditing ? 1.5 : 0.5,
        ),
      ),
      child: Row(children: [
        // 음식 아이콘
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _foodColor(food.name),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Icon(Icons.restaurant_rounded, size: 20,
              color: _foodColor(food.name).withOpacity(0.6))),
        ),
        const SizedBox(width: 12),

        // 이름 + 영양 요약
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(food.name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('${food.kcal.round()}kcal  탄 ${food.carb.round()}g  단 ${food.protein.round()}g',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),

        // 수정 버튼
        GestureDetector(
          onTap: onEdit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isEditing ? AppColors.green400 : AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isEditing ? AppColors.green400 : AppColors.border,
                  width: 0.5),
            ),
            child: Text('수정', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: isEditing ? Colors.white : AppColors.textSecondary)),
          ),
        ),
        const SizedBox(width: 8),

        // 삭제 버튼
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.gray200),
        ),
      ]),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 수정 패널 ("혹시 이 음식이었나요?" + 검색)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _EditPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final List<MealFood> searchResults;
  final ValueChanged<MealFood> onSelectAlt;

  const _EditPanel({
    required this.searchCtrl,
    required this.searchResults,
    required this.onSelectAlt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 검색창
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: _SearchBarWidget(controller: searchCtrl, hintText: '사용자 직접 검색'),
      ),

      // 검색 결과
      if (searchResults.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Column(children: searchResults.take(4).map((f) =>
              _SearchResultTile(food: f, onTap: () => onSelectAlt(f))).toList()),
        ),

      // AI 대안 제안
      if (searchResults.isEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('혹시 이 음식이었나요?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 8,
              crossAxisSpacing: 8, childAspectRatio: 2.8,
            ),
            itemCount: _FoodDB.alternatives.length,
            itemBuilder: (ctx, i) {
              final food = _FoodDB.alternatives[i];
              return GestureDetector(
                onTap: () => onSelectAlt(food),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: _foodColor(food.name),
                          borderRadius: BorderRadius.circular(6)),
                      child: Center(child: Icon(Icons.restaurant_rounded, size: 14,
                          color: _foodColor(food.name).withOpacity(0.6))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(food.name, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                        Text('${food.kcal.round()}kcal',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    )),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    ]);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공용 서브 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  const _SearchBarWidget({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.gray200, fontSize: 14),
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray200, size: 20),
      suffixIcon: controller.text.isNotEmpty
          ? GestureDetector(
              onTap: controller.clear,
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.gray200))
          : null,
      filled: true,
      fillColor: AppColors.gray50,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green400, width: 1.5)),
    ),
  );
}

class _SearchResultTile extends StatelessWidget {
  final MealFood food;
  final VoidCallback onTap;
  const _SearchResultTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: _foodColor(food.name), borderRadius: BorderRadius.circular(6)),
          child: Center(child: Icon(Icons.restaurant_rounded, size: 16,
              color: _foodColor(food.name).withOpacity(0.6))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(food.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary))),
        Text('${food.kcal.round()}kcal',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.green400),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 하단 저장 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BottomSaveBar extends StatelessWidget {
  final _ScreenState state;
  final int foodCount;
  final double totalKcal;
  final String mealLabel;
  final VoidCallback onSave;

  const _BottomSaveBar({
    required this.state, required this.foodCount, required this.totalKcal,
    required this.mealLabel, required this.onSave,
  });

  bool get _canSave =>
      (state == _ScreenState.confirmed || state == _ScreenState.editing) &&
      foodCount > 0;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
    ),
    padding: EdgeInsets.fromLTRB(16, 10, 16,
        MediaQuery.of(context).padding.bottom + 12),
    child: Row(children: [
      if (_canSave && foodCount > 0) ...[
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('총 칼로리',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text('${totalKcal.round()} kcal',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(width: 14),
      ],
      Expanded(child: ElevatedButton(
        onPressed: _canSave ? onSave : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canSave ? AppColors.green400 : AppColors.gray100,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gray100,
          disabledForegroundColor: AppColors.gray200,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          !_canSave
              ? '음식을 선택해주세요'
              : state == _ScreenState.editing
                  ? '수정 완료 후 추가하기'
                  : '$mealLabel에 $foodCount개 추가하기',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      )),
    ]),
  );
}
