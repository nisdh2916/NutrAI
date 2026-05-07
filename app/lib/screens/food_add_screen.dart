import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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

// 알레르겐 → 관련 키워드 매핑
// 설정 화면(settings_screen.dart)의 알레르기 카테고리와 1:1 매칭
const _allergenKeywords = <String, List<String>>{
  '유제품':  ['우유', '치즈', '버터', '요거트', '크림', '유청', '밀크', '라떼', '카푸치노', '아이스크림'],
  '견과류':  ['아몬드', '호두', '캐슈', '땅콩', '잣', '피스타치오', '마카다미아', '헤이즐넛', '피넛', '견과'],
  '갑각류':  ['새우', '게', '랍스터', '크랩', '대게'],
  '밀':     ['빵', '파스타', '면', '국수', '라면', '우동', '스파게티', '밀가루', '만두', '냉면', '소면', '떡볶이'],
  '글루텐':  ['빵', '파스타', '면', '국수', '라면', '우동', '밀가루'],
  '계란':    ['계란', '달걀', '에그', '오믈렛', '마요네즈', '스크램블'],
  '대두':    ['두부', '된장', '간장', '두유', '콩국수', '낫토', '청국장', '순두부', '콩'],
  '복숭아':  ['복숭아', '피치'],
  '토마토':  ['토마토', '케첩'],
  '고등어':  ['고등어'],
  '조개류':  ['조개', '홍합', '굴', '전복', '바지락', '오징어', '낙지', '문어'],
};

// 음식 이름에 해당하는 알레르겐 목록 반환
List<String> _detectAllergens(String foodName, String? userAllergy) {
  if (userAllergy == null || userAllergy.isEmpty) return [];
  final userAllergens = userAllergy.split(',').map((e) => e.trim()).toList();
  final found = <String>[];
  for (final allergen in userAllergens) {
    final keywords = _allergenKeywords[allergen];
    if (keywords == null) continue;
    if (keywords.any((kw) => foodName.contains(kw))) {
      found.add(allergen);
    }
  }
  return found;
}

Color _foodColor(String name) {
  const c = [
    Color(0xFFFCD34D), Color(0xFFF87171), Color(0xFFFB923C),
    Color(0xFF86EFAC), Color(0xFF93C5FD), Color(0xFFC4B5FD),
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
  final DateTime? initialDate; // null = 오늘
  const FoodAddScreen({super.key, this.initialMealLabel = '아침', this.initialDate});

  @override
  State<FoodAddScreen> createState() => _FoodAddScreenState();
}

class _FoodAddScreenState extends State<FoodAddScreen> {
  late String _mealLabel;
  _ScreenState _state = _ScreenState.initial;
  bool _saving = false;

  // AI 분석 결과 목록 (수정 가능)
  final List<MealFood> _detectedFoods = [];

  // 현재 수정 중인 항목 인덱스 (-1 = 없음)
  int _editingIndex = -1;

  // 선택/촬영된 이미지 경로
  String? _pickedImagePath;
  final _picker = ImagePicker();

  // 검색
  final TextEditingController _searchCtrl = TextEditingController();
  List<MealFood> _searchResults = [];

  static const _mealLabels = ['아침', '점심', '저녁', '기타'];
  static const _mealColors = [AppColors.breakfast, AppColors.lunch, AppColors.dinner, AppColors.snack];

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

  // ── DB 검색 (DB 결과 없으면 내장 목록으로 폴백) ──
  void _onSearch() async {
    final q = _searchCtrl.text;
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final appState = context.read<AppState>();
    final dbResults = await appState.searchFoods(q);
    if (dbResults.isNotEmpty) {
      setState(() {
        _searchResults = dbResults.map((f) => MealFood(
          name: f.foodName, carb: f.carbG,
          protein: f.proteinG, fat: f.fatG, kcal: f.kcal,
        )).toList();
      });
    } else {
      // 내장 음식 목록에서 검색
      setState(() => _searchResults = _FoodDB.search(q));
    }
  }

  // ── 카메라 촬영 ──
  Future<void> _onCamera() async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _pickedImagePath = picked.path;
      _state = _ScreenState.analyzing;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _detectedFoods..clear()..addAll(_FoodDB.aiDetected);
      _state = _ScreenState.confirmed;
    });
  }

  // ── 갤러리 선택 ──
  Future<void> _onGallery() async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _pickedImagePath = picked.path;
      _state = _ScreenState.analyzing;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _detectedFoods..clear()..addAll(_FoodDB.aiDetected);
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

    // 영양정보가 모두 0인 항목 자동 제거
    final validFoods = _detectedFoods.where(
      (f) => !(f.kcal == 0 && f.carb == 0 && f.protein == 0 && f.fat == 0),
    ).toList();

    if (validFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영양정보가 없는 음식만 있어요. 음식을 검색해서 추가해주세요.'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final mealType = MealEntity.typeFromLabel(_mealLabel);
      // Fix 1: 선택된 날짜 사용 (캘린더에서 다른 날짜 선택 시 반영)
      final eatenAt = widget.initialDate ?? DateTime.now();

      // Fix 2: 아침/점심/저녁은 하루 한 번만 허용
      if (mealType != 'snack') {
        final exists = await appState.hasMealTypeForDate(mealType, eatenAt);
        if (!mounted) return;
        if (exists) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_mealLabel 식단이 이미 기록되어 있어요. 기존 기록을 삭제 후 다시 추가해주세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // Fix 3: 같은 이름 메뉴 중복 시 servingCount 합산
      final Map<String, ({MealFood food, double count})> merged = {};
      for (final f in validFoods) {
        if (merged.containsKey(f.name)) {
          merged[f.name] = (food: merged[f.name]!.food, count: merged[f.name]!.count + 1.0);
        } else {
          merged[f.name] = (food: f, count: 1.0);
        }
      }

      final foodArgs = <({int foodId, double? amountG, double servingCount})>[];
      for (final entry in merged.values) {
        final fid = await appState.getOrCreateFood(
          name: entry.food.name, kcal: entry.food.kcal.toDouble(),
          carbG: entry.food.carb.toDouble(), proteinG: entry.food.protein.toDouble(),
          fatG: entry.food.fat.toDouble(),
        );
        foodArgs.add((foodId: fid, amountG: null, servingCount: entry.count));
      }

      await appState.saveMeal(
        mealType:  mealType,
        eatenAt:   eatenAt,
        photoPath: _pickedImagePath,
        foods:     foodArgs,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  double get _totalKcal =>
      _detectedFoods.fold(0.0, (s, f) => s + f.kcal);

  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
              SliverToBoxAdapter(child: _PhotoButtons(onCamera: _onCamera, onGallery: _onGallery)),
              SliverToBoxAdapter(child: _SearchBarWidget(
                controller: _searchCtrl,
                hintText: '음식 검색 (예: 비빔밥, 닭가슴살)',
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
                )
              else
                SliverToBoxAdapter(child: _QuickFoodGrid(
                  onSelect: (food) => setState(() {
                    _detectedFoods.add(food);
                    _state = _ScreenState.confirmed;
                  }),
                )),
            ],

            // ── 분석 중 ──
            if (_state == _ScreenState.analyzing)
              SliverToBoxAdapter(child: _AnalyzingWidget()),

            // ── AI 결과 + 수정 ──
            if (_state == _ScreenState.confirmed ||
                _state == _ScreenState.editing) ...[

              // 사진 완료 배너 (작게)
              SliverToBoxAdapter(child: _PhotoDoneBanner(
                imagePath: _pickedImagePath,
                onRetake: () => setState(() {
                  _state = _ScreenState.initial;
                  _detectedFoods.clear();
                  _editingIndex = -1;
                  _pickedImagePath = null;
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
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.brandDark),
                        const SizedBox(width: 4),
                        const Text('AI 분석 결과',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.brandDark)),
                      ]),
                    ),
                    const Spacer(),
                    Text('총 ${_totalKcal.round()}kcal',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSub,
                          fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),

              // 알레르기 경고 배너
              SliverToBoxAdapter(child: _AllergyWarningBanner(
                foods: _detectedFoods,
                userAllergy: context.watch<AppState>().user?.allergy,
              )),

              // 탐지된 음식 리스트
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DetectedFoodRow(
                    food:       _detectedFoods[i],
                    isEditing:  _editingIndex == i,
                    allergens:  _detectAllergens(
                      _detectedFoods[i].name,
                      context.read<AppState>().user?.allergy,
                    ),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line, width: 0.5),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.brand),
                        SizedBox(width: 6),
                        Text('음식 직접 추가', style: TextStyle(
                            fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w500)),
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
          saving:     _saving,
          onSave:     _onSave,
        ),
      ]),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.close_rounded, color: AppColors.text),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('음식 추가'),
    centerTitle: true,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.line),
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
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('끼니', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: -0.01)),
        ),
        Row(children: List.generate(labels.length, (i) {
          final isSel = selected == labels[i];
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(labels[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                decoration: BoxDecoration(
                  color: isSel ? colors[i] : AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(labels[i], style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    letterSpacing: -0.01,
                    color: isSel ? Colors.white : AppColors.textSub)),
              ),
            ),
          ));
        })),
      ]),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 사진 촬영/갤러리 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PhotoButtons extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _PhotoButtons({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Expanded(child: _PhotoBtn(
          icon: Icons.camera_alt_rounded, label: 'AI 카메라 촬영',
          sub: '자동 인식', bg: AppColors.brandSoft,
          iconBg: AppColors.brand, textColor: AppColors.brandText,
          onTap: onCamera)),
        const SizedBox(width: 10),
        Expanded(child: _PhotoBtn(
          icon: Icons.photo_library_rounded, label: '갤러리에서 선택',
          sub: '사진 불러오기', bg: AppColors.carbSoft,
          iconBg: AppColors.carb, textColor: AppColors.carb,
          onTap: onGallery)),
      ]),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color bg, iconBg, textColor;
  final VoidCallback onTap;
  const _PhotoBtn({required this.icon, required this.label,
      required this.sub, required this.bg, required this.iconBg,
      required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
            color: textColor, letterSpacing: -0.01)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.75))),
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
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brand),
        ),
        SizedBox(height: 12),
        Text('AI가 음식을 분석하고 있어요...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.brandText, letterSpacing: -0.01)),
        SizedBox(height: 4),
        Text('잠시만 기다려주세요',
            style: TextStyle(fontSize: 11, color: AppColors.brand)),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 사진 완료 배너 (작게)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PhotoDoneBanner extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onRetake;
  const _PhotoDoneBanner({this.imagePath, required this.onRetake});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (imagePath != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.file(
              File(imagePath!),
              width: double.infinity, height: 140, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.brand),
          const SizedBox(width: 8),
          const Expanded(child: Text('사진 분석 완료!',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.brandText, letterSpacing: -0.01))),
          GestureDetector(
            onTap: onRetake,
            child: const Row(children: [
              Icon(Icons.refresh_rounded, size: 14, color: AppColors.brandText),
              SizedBox(width: 2),
              Text('다시 촬영', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandText)),
            ]),
          ),
        ]),
      ),
    ]),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 탐지된 음식 한 행
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _DetectedFoodRow extends StatelessWidget {
  final MealFood food;
  final bool isEditing;
  final List<String> allergens;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _DetectedFoodRow({
    required this.food, required this.isEditing,
    required this.allergens,
    required this.onEdit, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isEditing ? AppColors.brandSoft : AppColors.surface,
        border: Border(
          bottom: const BorderSide(color: AppColors.lineSoft, width: 1),
          left: BorderSide(
              color: isEditing ? AppColors.brand : Colors.transparent, width: 3),
        ),
      ),
      child: Row(children: [
        // 컬러 박스
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _foodColor(food.name),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),

        // 이름 + 영양 요약 + 알레르기 뱃지
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(food.name, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.text, letterSpacing: -0.015))),
            if (allergens.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFEF4444)),
                  const SizedBox(width: 2),
                  Text('알레르기', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444))),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text('${food.kcal.round()}kcal · 탄 ${food.carb.round()}g · 단 ${food.protein.round()}g · 지 ${food.fat.round()}g',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (allergens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('⚠ ${allergens.join(', ')} 포함',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600)),
            ),
        ])),

        // 수정 버튼
        GestureDetector(
          onTap: onEdit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.lineSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('수정', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSub)),
          ),
        ),
        const SizedBox(width: 6),

        // 삭제 버튼
        GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
          ),
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
                  color: AppColors.text)),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line, width: 0.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: _foodColor(food.name),
                          borderRadius: BorderRadius.circular(6)),
                      child: Center(child: Icon(Icons.restaurant_rounded, size: 14,
                          color: _foodColor(food.name).withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(food.name, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.text),
                          overflow: TextOverflow.ellipsis),
                        Text('${food.kcal.round()}kcal',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSub)),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        )),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: controller.clear,
            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted)),
      ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: _foodColor(food.name),
              borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(food.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.text, letterSpacing: -0.01))),
        Text('${food.kcal.round()}kcal',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
        const SizedBox(width: 8),
        const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.brand),
      ]),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 알레르기 경고 배너
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _AllergyWarningBanner extends StatelessWidget {
  final List<MealFood> foods;
  final String? userAllergy;
  const _AllergyWarningBanner({required this.foods, this.userAllergy});

  @override
  Widget build(BuildContext context) {
    if (userAllergy == null || userAllergy!.isEmpty || foods.isEmpty) {
      return const SizedBox.shrink();
    }
    final triggered = <String>{};
    for (final f in foods) {
      triggered.addAll(_detectAllergens(f.name, userAllergy));
    }
    if (triggered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA), width: 1),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFEF4444)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('알레르기 주의!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626))),
            const SizedBox(height: 2),
            Text('${triggered.join(', ')} 성분이 포함된 음식이 있어요.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
          ])),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 하단 저장 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BottomSaveBar extends StatelessWidget {
  final _ScreenState state;
  final int foodCount;
  final double totalKcal;
  final String mealLabel;
  final bool saving;
  final VoidCallback onSave;

  const _BottomSaveBar({
    required this.state, required this.foodCount, required this.totalKcal,
    required this.mealLabel, required this.saving, required this.onSave,
  });

  bool get _canSave =>
      (state == _ScreenState.confirmed || state == _ScreenState.editing) &&
      foodCount > 0;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line, width: 1)),
    ),
    padding: EdgeInsets.fromLTRB(20, 12, 20,
        MediaQuery.of(context).padding.bottom + 16),
    child: Row(children: [
      if (_canSave && !saving) ...[
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('총 칼로리',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${totalKcal.round()}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.text, letterSpacing: -0.025)),
                const SizedBox(width: 2),
                const Text('kcal', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ]),
        ]),
        const SizedBox(width: 14),
      ],
      Expanded(child: GestureDetector(
        onTap: (!_canSave || saving)
            ? (!saving ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('아래 목록에서 음식을 선택하거나 검색해주세요'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              ) : null)
            : onSave,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _canSave ? AppColors.brand : AppColors.lineStrong,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  !_canSave
                      ? '음식을 선택하면 기록할 수 있어요'
                      : state == _ScreenState.editing
                          ? '수정 완료 후 추가하기'
                          : '$mealLabel에 $foodCount개 추가',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: _canSave ? Colors.white : AppColors.textMuted,
                    letterSpacing: -0.015,
                  ),
                ),
        ),
      )),
    ]),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 빠른 음식 선택 그리드 (초기 상태)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _QuickFoodGrid extends StatelessWidget {
  final ValueChanged<MealFood> onSelect;
  const _QuickFoodGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final foods = _FoodDB.all;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.brand),
          const SizedBox(width: 4),
          const Text('빠른 선택',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(width: 6),
          const Text('탭하면 바로 추가돼요',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
          ),
          itemCount: foods.length,
          itemBuilder: (ctx, i) {
            final food = foods[i];
            return GestureDetector(
              onTap: () => onSelect(food),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line, width: 0.5),
                  boxShadow: AppShadows.card,
                ),
                child: Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _foodColor(food.name),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(food.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.text),
                          overflow: TextOverflow.ellipsis),
                      Text('${food.kcal.round()}kcal',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted)),
                    ],
                  )),
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 16, color: AppColors.brand),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}
