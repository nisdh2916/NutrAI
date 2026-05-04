import '../models/db_models.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';

/// 끼니/음식 도메인 상태 및 비즈니스 로직.
/// AppState가 소유하며 notifyListeners 호출은 AppState에 위임.
class MealState {
  final _mealRepo = MealRepository();
  final _foodRepo = FoodRepository();

  List<MealWithFoods> _todayMeals = [];
  List<MealWithFoods> get todayMeals => _todayMeals;

  double get todayKcal     => _todayMeals.fold(0.0, (s, m) => s + m.totalKcal);
  double get todayCarbG    => _todayMeals.fold(0.0, (s, m) => s + m.totalCarbG);
  double get todayProteinG => _todayMeals.fold(0.0, (s, m) => s + m.totalProteinG);
  double get todayFatG     => _todayMeals.fold(0.0, (s, m) => s + m.totalFatG);

  Future<void> loadToday(int userId) async {
    _todayMeals = await _mealRepo.getTodayMeals(userId);
  }

  Future<List<MealWithFoods>> getMealsForDate(int userId, DateTime date) =>
      _mealRepo.getMealsForDate(userId, date);

  Future<int> getOrCreateFood({
    required String name,
    required double kcal,
    required double carbG,
    required double proteinG,
    required double fatG,
  }) async {
    final results = await _foodRepo.searchFoods(name);
    final exact = results.where((f) => f.foodName == name).firstOrNull;
    if (exact != null) return exact.id!;
    final now = DateTime.now().toIso8601String();
    return _foodRepo.createFood(FoodEntity(
      foodName: name, kcal: kcal,
      carbG: carbG, proteinG: proteinG, fatG: fatG,
      createdAt: now, updatedAt: now,
    ));
  }

  Future<void> saveMeal({
    required int userId,
    required String mealType,
    required DateTime eatenAt,
    String? memo,
    String? photoPath,
    required List<({int foodId, double? amountG, double servingCount})> foods,
  }) async {
    await _mealRepo.saveMealWithFoods(
      userId:   userId,
      mealType: mealType,
      eatenAt:  eatenAt,
      memo:     memo,
      foods:    foods,
    );
    await loadToday(userId);
  }

  Future<void> deleteMeal(int mealId, int userId) async {
    await _mealRepo.deleteMeal(mealId);
    await loadToday(userId);
  }

  Future<Map<String, double>> getWeeklyKcal(int userId, DateTime startOfWeek) =>
      _mealRepo.getWeeklyKcal(userId, startOfWeek);

  Future<Map<String, double>> getMonthlyKcal(int userId, int year, int month) =>
      _mealRepo.getMonthlyKcal(userId, year, month);

  Future<List<String>> getRecordedDates(int userId, DateTime from, DateTime to) =>
      _mealRepo.getRecordedDates(userId, from, to);

  Future<List<FoodEntity>> searchFoods(String query) =>
      _foodRepo.searchFoods(query);

  Future<List<FoodEntity>> getAllFoods() =>
      _foodRepo.getAllFoods();

  void clear() => _todayMeals = [];
}
