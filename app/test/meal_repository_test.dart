import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/models/db_models.dart';
import 'package:nutrai/repositories/food_repository.dart';
import 'package:nutrai/repositories/meal_repository.dart';
import 'package:nutrai/repositories/user_repository.dart';
import 'helpers/db_test_helper.dart';

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late MealRepository repo;
  late FoodRepository foodRepo;
  late UserRepository userRepo;
  late int userId;

  setUp(() async {
    repo = MealRepository();
    foodRepo = FoodRepository();
    userRepo = UserRepository();
    final now = DateTime.now().toIso8601String();
    userId = await userRepo.createUser(UserProfileEntity(
      nickname: '테스트유저', createdAt: now, updatedAt: now,
    ));
  });

  Future<int> seedFood() async {
    final now = DateTime.now().toIso8601String();
    return foodRepo.createFood(FoodEntity(
      foodName: '테스트음식', kcal: 200.0,
      carbG: 30.0, proteinG: 10.0, fatG: 5.0,
      createdAt: now, updatedAt: now,
    ));
  }

  group('MealRepository - saveMealWithFoods', () {
    test('creates meal and returns positive id', () async {
      final foodId = await seedFood();
      final id = await repo.saveMealWithFoods(
        userId: userId,
        mealType: 'lunch',
        eatenAt: DateTime.now(),
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(id, greaterThan(0));
    });

    test('getMealsForDate returns saved meal', () async {
      final foodId = await seedFood();
      final today = DateTime.now();
      await repo.saveMealWithFoods(
        userId: userId,
        mealType: 'dinner',
        eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.5)],
      );
      final meals = await repo.getMealsForDate(userId, today);
      expect(meals.length, 1);
      expect(meals.first.meal.mealType, 'dinner');
    });

    test('saved foods are retrievable in meal', () async {
      final foodId = await seedFood();
      final today = DateTime.now();
      await repo.saveMealWithFoods(
        userId: userId,
        mealType: 'breakfast',
        eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 2.0)],
      );
      final meals = await repo.getMealsForDate(userId, today);
      expect(meals.first.foods.length, 1);
      expect(meals.first.foods.first.mealFood.servingCount, 2.0);
    });

    test('multiple foods in one meal', () async {
      final id1 = await seedFood();
      final now2 = DateTime.now().toIso8601String();
      final id2 = await foodRepo.createFood(FoodEntity(
        foodName: '두번째음식', kcal: 150.0,
        carbG: 20.0, proteinG: 8.0, fatG: 3.0,
        createdAt: now2, updatedAt: now2,
      ));
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'lunch', eatenAt: DateTime.now(),
        foods: [
          (foodId: id1, amountG: null, servingCount: 1.0),
          (foodId: id2, amountG: null, servingCount: 0.5),
        ],
      );
      final meals = await repo.getMealsForDate(userId, DateTime.now());
      expect(meals.first.foods.length, 2);
    });
  });

  group('MealRepository - getMealsForDate', () {
    test('returns empty list when no meals', () async {
      final meals = await repo.getMealsForDate(userId, DateTime.now());
      expect(meals, isEmpty);
    });

    test('isolates meals by user', () async {
      final foodId = await seedFood();
      final now2 = DateTime.now().toIso8601String();
      final userId2 = await userRepo.createUser(UserProfileEntity(
        nickname: '유저2', createdAt: now2, updatedAt: now2,
      ));
      final today = DateTime.now();
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'lunch', eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(await repo.getMealsForDate(userId, today), hasLength(1));
      expect(await repo.getMealsForDate(userId2, today), isEmpty);
    });

    test('does not return meals from different date', () async {
      final foodId = await seedFood();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'lunch', eatenAt: yesterday,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(await repo.getMealsForDate(userId, DateTime.now()), isEmpty);
    });
  });

  group('MealRepository - deleteMeal', () {
    test('removes meal from getMealsForDate', () async {
      final foodId = await seedFood();
      final today = DateTime.now();
      final mealId = await repo.saveMealWithFoods(
        userId: userId, mealType: 'lunch', eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      await repo.deleteMeal(mealId);
      expect(await repo.getMealsForDate(userId, today), isEmpty);
    });
  });

  group('MealRepository - hasMealTypeForDate', () {
    test('returns false when meal type not recorded', () async {
      final result = await repo.hasMealTypeForDate(userId, 'breakfast', DateTime.now());
      expect(result, false);
    });

    test('returns true after saving that meal type', () async {
      final foodId = await seedFood();
      final today = DateTime.now();
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'breakfast', eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(await repo.hasMealTypeForDate(userId, 'breakfast', today), true);
    });

    test('returns false for different meal type', () async {
      final foodId = await seedFood();
      final today = DateTime.now();
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'breakfast', eatenAt: today,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(await repo.hasMealTypeForDate(userId, 'lunch', today), false);
    });
  });

  group('MealRepository - getRecordedDates', () {
    test('returns empty list when no meals', () async {
      expect(await repo.getRecordedDates(userId, DateTime(2024, 1, 1), DateTime(2024, 1, 31)), isEmpty);
    });

    test('returns dates with meals in range', () async {
      final foodId = await seedFood();
      final date = DateTime(2024, 6, 15, 12);
      await repo.saveMealWithFoods(
        userId: userId, mealType: 'lunch', eatenAt: date,
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      final dates = await repo.getRecordedDates(userId, DateTime(2024, 6, 1), DateTime(2024, 6, 30));
      expect(dates, contains('2024-06-15'));
    });
  });
}
