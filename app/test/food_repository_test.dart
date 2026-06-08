import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/database/food_data.dart';
import 'package:nutrai/models/db_models.dart';
import 'package:nutrai/repositories/food_repository.dart';
import 'helpers/db_test_helper.dart';

const _baseSeedFoodCount = 12;

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late FoodRepository repo;
  setUp(() => repo = FoodRepository());

  FoodEntity makeFood({String name = '테스트음식', double kcal = 200.0}) {
    final now = DateTime.now().toIso8601String();
    return FoodEntity(
      foodName: name,
      kcal: kcal,
      carbG: 30.0,
      proteinG: 10.0,
      fatG: 5.0,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('FoodRepository - getAllFoods', () {
    test('returns sample and generated nutrition seed data on fresh DB',
        () async {
      final foods = await repo.getAllFoods();
      expect(foods.length, _baseSeedFoodCount + kFoodData.length);
    });

    test('returns foods ordered by food_name', () async {
      final foods = await repo.getAllFoods();
      final names = foods.map((f) => f.foodName).toList();
      expect(names, orderedEquals(names..sort()));
    });
  });

  group('FoodRepository - getFoodById', () {
    test('returns null for nonexistent id', () async {
      expect(await repo.getFoodById(9999), isNull);
    });

    test('returns correct food by seed id', () async {
      final food = await repo.getFoodById(1);
      expect(food, isNotNull);
      expect(food!.foodName, '밥');
    });
  });

  group('FoodRepository - getByExactName', () {
    test('returns null for unknown name', () async {
      expect(await repo.getByExactName('존재하지않는음식'), isNull);
    });

    test('finds seeded food by exact name', () async {
      final food = await repo.getByExactName('밥');
      expect(food, isNotNull);
      expect(food!.kcal, 300.0);
    });

    test('does not match partial name', () async {
      expect(await repo.getByExactName('밥류'), isNull);
    });
  });

  group('FoodRepository - searchFoods', () {
    test('empty query returns all foods', () async {
      final all = await repo.getAllFoods();
      final searched = await repo.searchFoods('');
      expect(searched.length, all.length);
    });

    test('finds matching food by partial name', () async {
      final results = await repo.searchFoods('고구마');
      expect(results.any((f) => f.foodName == '고구마'), true);
    });

    test('returns empty list for no match', () async {
      final results = await repo.searchFoods('xyznonexistent');
      expect(results, isEmpty);
    });
  });

  group('FoodRepository - createFood', () {
    test('returns positive id', () async {
      final id = await repo.createFood(makeFood());
      expect(id, greaterThan(0));
    });

    test('created food retrievable by id', () async {
      final id = await repo.createFood(makeFood(name: '새음식', kcal: 250.0));
      final food = await repo.getFoodById(id);
      expect(food!.foodName, '새음식');
      expect(food.kcal, 250.0);
    });
  });

  group('FoodRepository - updateFood', () {
    test('updates kcal', () async {
      final id = await repo.createFood(makeFood(kcal: 100.0));
      final food = await repo.getFoodById(id);
      final updated = FoodEntity(
        id: food!.id,
        foodName: food.foodName,
        kcal: 999.0,
        carbG: food.carbG,
        proteinG: food.proteinG,
        fatG: food.fatG,
        createdAt: food.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await repo.updateFood(updated);
      expect((await repo.getFoodById(id))!.kcal, 999.0);
    });
  });

  group('FoodRepository - deleteFood', () {
    test('removes food by id', () async {
      final id = await repo.createFood(makeFood());
      await repo.deleteFood(id);
      expect(await repo.getFoodById(id), isNull);
    });
  });

  group('FoodRepository - getFoodsByIds', () {
    test('returns empty list for empty ids', () async {
      expect(await repo.getFoodsByIds([]), isEmpty);
    });

    test('returns foods matching given ids', () async {
      final foods = await repo.getFoodsByIds([1, 2]);
      expect(foods.length, 2);
      expect(foods.map((f) => f.id).toSet(), {1, 2});
    });
  });
}
