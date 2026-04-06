import 'package:flutter/foundation.dart';
import '../models/db_models.dart';
import '../database/database_helper.dart';
import '../repositories/user_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/food_repository.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AppState: 앱 전역 상태 (Provider로 제공)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AppState extends ChangeNotifier {
  final _userRepo = UserRepository();
  final _mealRepo = MealRepository();
  final _foodRepo = FoodRepository();

  // ── 상태 ────────────────────────────────────────
  UserProfileEntity? _user;
  List<MealWithFoods> _todayMeals = [];
  bool _loading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────
  UserProfileEntity? get user      => _user;
  List<MealWithFoods> get todayMeals => _todayMeals;
  bool get loading    => _loading;
  String? get error   => _error;

  int? get userId     => _user?.id;

  double get todayKcal    => _todayMeals.fold(0.0, (s, m) => s + m.totalKcal);
  double get todayCarbG   => _todayMeals.fold(0.0, (s, m) => s + m.totalCarbG);
  double get todayProteinG=> _todayMeals.fold(0.0, (s, m) => s + m.totalProteinG);
  double get todayFatG    => _todayMeals.fold(0.0, (s, m) => s + m.totalFatG);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 앱 초기화 (main에서 호출)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> init() async {
    _setLoading(true);
    try {
      _user = await _userRepo.getFirstUser();
      if (_user != null) await loadTodayMeals();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 사용자
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> saveUser({
    required String nickname,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    double? targetKcal,
  }) async {
    final now = DateTime.now().toIso8601String();

    if (_user == null) {
      // 신규 생성
      final newUser = UserProfileEntity(
        nickname:      nickname,
        gender:        gender,
        age:           age,
        heightCm:      heightCm,
        weightKg:      weightKg,
        activityLevel: activityLevel,
        targetKcal:    targetKcal,
        createdAt:     now,
        updatedAt:     now,
      );
      final id = await _userRepo.createUser(newUser);
      _user = await _userRepo.getUserById(id);
    } else {
      // 수정
      final updated = _user!.copyWith(
        nickname:      nickname,
        gender:        gender,
        age:           age,
        heightCm:      heightCm,
        weightKg:      weightKg,
        activityLevel: activityLevel,
        targetKcal:    targetKcal,
        updatedAt:     now,
      );
      await _userRepo.updateUser(updated);
      _user = updated;
    }
    notifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 오늘 식단
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> loadTodayMeals() async {
    if (userId == null) return;
    _todayMeals = await _mealRepo.getTodayMeals(userId!);
    notifyListeners();
  }

  /// 특정 날짜 식단 조회
  Future<List<MealWithFoods>> getMealsForDate(DateTime date) async {
    if (userId == null) return [];
    return _mealRepo.getMealsForDate(userId!, date);
  }

  /// 끼니 + 음식 저장
  Future<void> saveMeal({
    required String mealType,
    required DateTime eatenAt,
    String? memo,
    required List<({int foodId, double? amountG, double servingCount})> foods,
  }) async {
    if (userId == null) return;
    await _mealRepo.saveMealWithFoods(
      userId:   userId!,
      mealType: mealType,
      eatenAt:  eatenAt,
      memo:     memo,
      foods:    foods,
    );
    await loadTodayMeals();
  }

  /// 끼니 삭제
  Future<void> deleteMeal(int mealId) async {
    await _mealRepo.deleteMeal(mealId);
    await loadTodayMeals();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 주간 / 월간 칼로리 (리포트용)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<Map<String, double>> getWeeklyKcal(DateTime startOfWeek) async {
    if (userId == null) return {};
    return _mealRepo.getWeeklyKcal(userId!, startOfWeek);
  }

  Future<Map<String, double>> getMonthlyKcal(int year, int month) async {
    if (userId == null) return {};
    return _mealRepo.getMonthlyKcal(userId!, year, month);
  }

  Future<List<String>> getRecordedDates(DateTime from, DateTime to) async {
    if (userId == null) return [];
    return _mealRepo.getRecordedDates(userId!, from, to);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 음식 검색 (FoodAddScreen에서 사용)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<FoodEntity>> searchFoods(String query) =>
      _foodRepo.searchFoods(query);

  Future<List<FoodEntity>> getAllFoods() =>
      _foodRepo.getAllFoods();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 사용자 초기화 (프로필 재설정 / 로그아웃)
  // 설정 화면에서 호출 → _RootRouter가 온보딩으로 전환
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> resetUser() async {
    _setLoading(true);
    try {
      // DB 전체 초기화 후 샘플 데이터 재삽입
      await DatabaseHelper.instance.deleteDatabase();
      // deleteDatabase 후 _db가 null이 되므로 재초기화
      await DatabaseHelper.instance.database;
      _user       = null;
      _todayMeals = [];
    } finally {
      _setLoading(false); // notifyListeners 포함 → _RootRouter가 온보딩으로 전환
    }
  }

  // ── 내부 ────────────────────────────────────────
  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
