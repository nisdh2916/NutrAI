import 'package:flutter/foundation.dart';
import '../models/db_models.dart';
import '../database/database_helper.dart';
import 'user_state.dart';
import 'meal_state.dart';

export 'user_state.dart';
export 'meal_state.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AppState: 파사드 ChangeNotifier
// 도메인 로직은 UserState / MealState에 위임.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AppState extends ChangeNotifier {
  final _userState = UserState();
  final _mealState = MealState();

  bool _loading = false;
  String? _error;

  // ── 위임 Getters ─────────────────────────────────
  UserProfileEntity? get user        => _userState.user;
  int? get userId                    => _userState.userId;
  List<MealWithFoods> get todayMeals => _mealState.todayMeals;
  bool get loading                   => _loading;
  String? get error                  => _error;

  double get todayKcal     => _mealState.todayKcal;
  double get todayCarbG    => _mealState.todayCarbG;
  double get todayProteinG => _mealState.todayProteinG;
  double get todayFatG     => _mealState.todayFatG;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 앱 초기화
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> init() async {
    _setLoading(true);
    try {
      await _userState.load();
      if (userId != null) await _mealState.loadToday(userId!);
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
    String? goal,
    String? allergy,
    String? condition,
  }) async {
    await _userState.save(
      nickname:      nickname,
      gender:        gender,
      age:           age,
      heightCm:      heightCm,
      weightKg:      weightKg,
      activityLevel: activityLevel,
      targetKcal:    targetKcal,
      goal:          goal,
      allergy:       allergy,
      condition:     condition,
    );
    notifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 오늘 식단
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> loadTodayMeals() async {
    if (userId == null) return;
    await _mealState.loadToday(userId!);
    notifyListeners();
  }

  Future<List<MealWithFoods>> getMealsForDate(DateTime date) async {
    if (userId == null) return [];
    return _mealState.getMealsForDate(userId!, date);
  }

  Future<int> getOrCreateFood({
    required String name,
    required double kcal,
    required double carbG,
    required double proteinG,
    required double fatG,
  }) => _mealState.getOrCreateFood(
    name: name, kcal: kcal,
    carbG: carbG, proteinG: proteinG, fatG: fatG,
  );

  Future<void> saveMeal({
    required String mealType,
    required DateTime eatenAt,
    String? memo,
    String? photoPath,
    required List<({int foodId, double? amountG, double servingCount})> foods,
  }) async {
    if (userId == null) return;
    await _mealState.saveMeal(
      userId:   userId!,
      mealType: mealType,
      eatenAt:  eatenAt,
      memo:     memo,
      foods:    foods,
    );
    notifyListeners();
  }

  Future<void> deleteMeal(int mealId) async {
    if (userId == null) return;
    await _mealState.deleteMeal(mealId, userId!);
    notifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 주간 / 월간 칼로리 (리포트용)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Map<String, double>> getWeeklyKcal(DateTime startOfWeek) async {
    if (userId == null) return {};
    return _mealState.getWeeklyKcal(userId!, startOfWeek);
  }

  Future<Map<String, double>> getMonthlyKcal(int year, int month) async {
    if (userId == null) return {};
    return _mealState.getMonthlyKcal(userId!, year, month);
  }

  Future<List<String>> getRecordedDates(DateTime from, DateTime to) async {
    if (userId == null) return [];
    return _mealState.getRecordedDates(userId!, from, to);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 음식 검색
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<List<FoodEntity>> searchFoods(String query) =>
      _mealState.searchFoods(query);

  Future<List<FoodEntity>> getAllFoods() =>
      _mealState.getAllFoods();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 사용자 초기화 (프로필 재설정 / 로그아웃)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> resetUser() async {
    _setLoading(true);
    try {
      await DatabaseHelper.instance.deleteDatabase();
      await DatabaseHelper.instance.database;
      _userState.clear();
      _mealState.clear();
    } finally {
      _setLoading(false);
    }
  }

  // ── 내부 ────────────────────────────────────────
  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
