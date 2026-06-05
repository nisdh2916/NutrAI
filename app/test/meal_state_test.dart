import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/database/food_data.dart';
import 'package:nutrai/providers/meal_state.dart';
import 'package:nutrai/providers/user_state.dart';
import 'helpers/db_test_helper.dart';

const _baseSeedFoodCount = 12;

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late MealState state;
  late UserState userState;

  setUp(() async {
    state = MealState();
    userState = UserState();
    // UserState.save는 내부적으로 repo를 통해 DB에 사용자를 생성
    await userState.save(nickname: '테스트유저', gender: '남', age: 25);
  });

  group('MealState - initial aggregates', () {
    test('todayKcal is zero when no meals', () {
      expect(state.todayKcal, 0.0);
    });

    test('todayCarbG is zero when no meals', () {
      expect(state.todayCarbG, 0.0);
    });

    test('todayProteinG is zero when no meals', () {
      expect(state.todayProteinG, 0.0);
    });

    test('todayFatG is zero when no meals', () {
      expect(state.todayFatG, 0.0);
    });

    test('todayMeals is empty list initially', () {
      expect(state.todayMeals, isEmpty);
    });
  });

  group('MealState - getOrCreateFood', () {
    test('creates new food and returns id', () async {
      final id = await state.getOrCreateFood(
        name: '새음식',
        kcal: 200.0,
        carbG: 30.0,
        proteinG: 10.0,
        fatG: 5.0,
      );
      expect(id, greaterThan(0));
    });

    test('returns same id for existing food', () async {
      final id1 = await state.getOrCreateFood(
        name: '중복음식',
        kcal: 100.0,
        carbG: 10.0,
        proteinG: 5.0,
        fatG: 2.0,
      );
      final id2 = await state.getOrCreateFood(
        name: '중복음식',
        kcal: 100.0,
        carbG: 10.0,
        proteinG: 5.0,
        fatG: 2.0,
      );
      expect(id1, id2);
    });
  });

  group('MealState - loadToday', () {
    test('todayMeals populated after saveMeal + loadToday', () async {
      final userId = userState.userId!;
      final foodId = await state.getOrCreateFood(
        name: '테스트음식',
        kcal: 300.0,
        carbG: 50.0,
        proteinG: 10.0,
        fatG: 5.0,
      );
      await state.saveMeal(
        userId: userId,
        mealType: 'lunch',
        eatenAt: DateTime.now(),
        foods: [(foodId: foodId, amountG: null, servingCount: 1.0)],
      );
      expect(state.todayMeals.length, 1);
    });
  });

  group('MealState - searchFoods', () {
    test('returns seed foods on search', () async {
      final results = await state.searchFoods('밥');
      expect(results.any((f) => f.foodName == '밥'), true);
    });

    test('getAllFoods returns sample and generated nutrition seed items',
        () async {
      final foods = await state.getAllFoods();
      expect(foods.length, _baseSeedFoodCount + kFoodData.length);
    });
  });

  group('MealState - clear', () {
    test('clears todayMeals', () {
      state.clear();
      expect(state.todayMeals, isEmpty);
      expect(state.todayKcal, 0.0);
    });
  });
}
