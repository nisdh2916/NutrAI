import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/models/db_models.dart';

const _now = '2026-01-01T12:00:00';

FoodEntity _food({
  required String name,
  double kcal = 100,
  double carb = 20,
  double protein = 10,
  double fat = 5,
}) =>
    FoodEntity(
      foodName: name,
      kcal: kcal,
      carbG: carb,
      proteinG: protein,
      fatG: fat,
      createdAt: _now,
      updatedAt: _now,
    );

MealFoodEntity _mealFood({double serving = 1.0, double? amountG}) =>
    MealFoodEntity(
      mealId: 1,
      foodId: 1,
      servingCount: serving,
      amountG: amountG,
      createdAt: _now,
      updatedAt: _now,
    );

MealEntity _meal({String type = 'lunch'}) => MealEntity(
      userId: 1,
      mealType: type,
      eatenAt: _now,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  group('MealFoodJoin — 영양소 합산', () {
    test('서빙 1.0: 원래 값 그대로', () {
      final join = MealFoodJoin(
        food: _food(name: '닭가슴살', kcal: 165, carb: 0, protein: 31, fat: 3),
        mealFood: _mealFood(serving: 1.0),
      );
      expect(join.totalKcal, 165.0);
      expect(join.totalCarbG, 0.0);
      expect(join.totalProteinG, 31.0);
      expect(join.totalFatG, 3.0);
    });

    test('서빙 2.0: 두 배', () {
      final join = MealFoodJoin(
        food: _food(name: '밥', kcal: 300, carb: 68, protein: 6, fat: 1),
        mealFood: _mealFood(serving: 2.0),
      );
      expect(join.totalKcal, 600.0);
      expect(join.totalCarbG, 136.0);
      expect(join.totalProteinG, 12.0);
      expect(join.totalFatG, 2.0);
    });

    test('서빙 0.5: 절반', () {
      final join = MealFoodJoin(
        food: _food(name: '고구마', kcal: 128),
        mealFood: _mealFood(serving: 0.5),
      );
      expect(join.totalKcal, 64.0);
    });
  });

  group('MealWithFoods — 끼니 합산', () {
    test('음식 없으면 모두 0', () {
      final meal = MealWithFoods(meal: _meal(), foods: []);
      expect(meal.totalKcal, 0.0);
      expect(meal.totalCarbG, 0.0);
      expect(meal.totalProteinG, 0.0);
      expect(meal.totalFatG, 0.0);
    });

    test('단일 음식 합산', () {
      final meal = MealWithFoods(
        meal: _meal(),
        foods: [
          MealFoodJoin(
            food: _food(name: '계란', kcal: 90, carb: 1, protein: 7, fat: 6),
            mealFood: _mealFood(),
          ),
        ],
      );
      expect(meal.totalKcal, 90.0);
      expect(meal.totalProteinG, 7.0);
    });

    test('여러 음식 합산', () {
      final meal = MealWithFoods(
        meal: _meal(),
        foods: [
          MealFoodJoin(
            food: _food(name: '밥', kcal: 310, carb: 68, protein: 5, fat: 1),
            mealFood: _mealFood(),
          ),
          MealFoodJoin(
            food: _food(name: '된장찌개', kcal: 180, carb: 12, protein: 14, fat: 7),
            mealFood: _mealFood(),
          ),
        ],
      );
      expect(meal.totalKcal, 490.0);
      expect(meal.totalCarbG, 80.0);
      expect(meal.totalProteinG, 19.0);
      expect(meal.totalFatG, 8.0);
    });

    test('서빙 수 반영한 합산', () {
      final meal = MealWithFoods(
        meal: _meal(),
        foods: [
          MealFoodJoin(
            food: _food(name: '밥', kcal: 310),
            mealFood: _mealFood(serving: 2.0),
          ),
        ],
      );
      expect(meal.totalKcal, 620.0);
    });
  });

  group('MealWithFoods.summary', () {
    test('음식 없으면 —', () {
      expect(MealWithFoods(meal: _meal(), foods: []).summary, '—');
    });

    test('음식 1개: 음식명만', () {
      final meal = MealWithFoods(
        meal: _meal(),
        foods: [
          MealFoodJoin(
            food: _food(name: '닭가슴살'),
            mealFood: _mealFood(),
          ),
        ],
      );
      expect(meal.summary, '닭가슴살');
    });

    test('음식 3개: "첫번째음식 외 2개"', () {
      final meal = MealWithFoods(
        meal: _meal(),
        foods: [
          MealFoodJoin(food: _food(name: '밥'), mealFood: _mealFood()),
          MealFoodJoin(food: _food(name: '김치'), mealFood: _mealFood()),
          MealFoodJoin(food: _food(name: '계란'), mealFood: _mealFood()),
        ],
      );
      expect(meal.summary, '밥 외 2개');
    });
  });

  group('MealEntity.label — 한국어 변환', () {
    test('breakfast → 아침', () {
      expect(_meal(type: 'breakfast').label, '아침');
    });
    test('lunch → 점심', () {
      expect(_meal(type: 'lunch').label, '점심');
    });
    test('dinner → 저녁', () {
      expect(_meal(type: 'dinner').label, '저녁');
    });
    test('snack → 간식', () {
      expect(_meal(type: 'snack').label, '간식');
    });
    test('알 수 없는 값 → 원문 그대로', () {
      expect(_meal(type: 'brunch').label, 'brunch');
    });
  });

  group('MealEntity.typeFromLabel — 영어 변환', () {
    test('아침 → breakfast', () {
      expect(MealEntity.typeFromLabel('아침'), 'breakfast');
    });
    test('점심 → lunch', () {
      expect(MealEntity.typeFromLabel('점심'), 'lunch');
    });
    test('저녁 → dinner', () {
      expect(MealEntity.typeFromLabel('저녁'), 'dinner');
    });
    test('간식 → snack', () {
      expect(MealEntity.typeFromLabel('간식'), 'snack');
    });
    test('알 수 없는 값 → breakfast(기본값)', () {
      expect(MealEntity.typeFromLabel('야식'), 'breakfast');
    });
  });
}
