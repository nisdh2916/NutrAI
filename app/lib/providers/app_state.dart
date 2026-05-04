import 'package:flutter/foundation.dart';
import '../models/db_models.dart';
import '../database/database_helper.dart';
import 'user_state.dart';
import 'meal_state.dart';

export 'user_state.dart';
export 'meal_state.dart';

/// AppState 로딩 단계.
/// loading 플래그 + error 문자열 조합 대신 명시적 enum으로 상태 전이를 표현.
enum LoadingState { idle, loading, success, error }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AppState: 파사드 ChangeNotifier
// 도메인 로직은 UserState / MealState에 위임.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AppState extends ChangeNotifier {
  final _userState = UserState();
  final _mealState = MealState();

  LoadingState _state = LoadingState.idle;
  String? _error;

  // ── 위임 Getters ─────────────────────────────────
  UserProfileEntity? get user        => _userState.user;
  int? get userId                    => _userState.userId;
  List<MealWithFoods> get todayMeals => _mealState.todayMeals;
  LoadingState get state             => _state;
  /// 기존 코드 호환용 — 신규 코드는 `state`를 직접 사용 권장
  bool get loading                   => _state == LoadingState.loading;
  String? get error                  => _error;
  bool get hasError                  => _state == LoadingState.error;

  double get todayKcal     => _mealState.todayKcal;
  double get todayCarbG    => _mealState.todayCarbG;
  double get todayProteinG => _mealState.todayProteinG;
  double get todayFatG     => _mealState.todayFatG;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 앱 초기화
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> init() async {
    _setState(LoadingState.loading);
    try {
      await _userState.load();
      if (userId != null) await _mealState.loadToday(userId!);
      _error = null;
      _setState(LoadingState.success);
    } catch (e) {
      _error = e.toString();
      _setState(LoadingState.error);
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
    _setState(LoadingState.loading);
    try {
      await DatabaseHelper.instance.deleteDatabase();
      await DatabaseHelper.instance.database;
      _userState.clear();
      _mealState.clear();
      _error = null;
      _setState(LoadingState.idle);
    } catch (e) {
      _error = e.toString();
      _setState(LoadingState.error);
    }
  }

  // ── 내부 ────────────────────────────────────────
  void _setState(LoadingState s) {
    _state = s;
    notifyListeners();
  }
}
