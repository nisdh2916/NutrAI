import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/models/chat_models.dart';

void main() {
  group('RecommendMenuItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': '닭가슴살 샐러드',
        'kcal': 300,
        'carb': 15,
        'protein': 35,
        'fat': 8,
        'reason': '고단백 저지방',
        'tags': ['#다이어트'],
        'allergen_warning': true,
        'allergen_names': ['계란'],
      };
      final item = RecommendMenuItem.fromJson(json);
      expect(item.name, '닭가슴살 샐러드');
      expect(item.kcal, 300.0);
      expect(item.carb, 15.0);
      expect(item.protein, 35.0);
      expect(item.fat, 8.0);
      expect(item.reason, '고단백 저지방');
      expect(item.tags, ['#다이어트']);
      expect(item.allergenWarning, true);
      expect(item.allergenNames, ['계란']);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final item = RecommendMenuItem.fromJson({'name': '밥'});
      expect(item.kcal, 0.0);
      expect(item.tags, isEmpty);
      expect(item.allergenWarning, false);
      expect(item.allergenNames, isEmpty);
    });

    test('fromJson converts int kcal to double', () {
      final item = RecommendMenuItem.fromJson({'name': '밥', 'kcal': 300});
      expect(item.kcal, isA<double>());
    });
  });

  group('RecommendResult', () {
    final json = {
      'items': [
        {'name': '닭가슴살', 'kcal': 165},
        {'name': '현미밥', 'kcal': 200},
      ],
      'coaching': '균형 잡힌 식사를 하세요.',
    };

    test('fromJson parses items list', () {
      final result = RecommendResult.fromJson(json);
      expect(result.items.length, 2);
      expect(result.items[0].name, '닭가슴살');
    });

    test('fromJson parses coaching', () {
      final result = RecommendResult.fromJson(json);
      expect(result.coaching, '균형 잡힌 식사를 하세요.');
    });

    test('fromJson handles missing coaching', () {
      final result = RecommendResult.fromJson({'items': []});
      expect(result.coaching, '');
    });

    test('fromJson handles empty items', () {
      final result = RecommendResult.fromJson({'items': [], 'coaching': ''});
      expect(result.items, isEmpty);
    });
  });

  group('ExtractedProfile', () {
    final fullJson = {
      'name': '홍길동',
      'gender': '남',
      'age': 28,
      'height': 175.0,
      'weight': 70.0,
      'goal': '근육 증진',
      'activity_level': '높음',
      'allergy': '유제품',
      'condition': null,
      'reply': '모든 정보를 확인했어요!',
    };

    test('fromJson parses full profile', () {
      final p = ExtractedProfile.fromJson(fullJson);
      expect(p.name, '홍길동');
      expect(p.gender, '남');
      expect(p.age, 28);
      expect(p.height, 175.0);
      expect(p.weight, 70.0);
      expect(p.goal, '근육 증진');
      expect(p.activityLevel, '높음');
      expect(p.allergy, '유제품');
      expect(p.condition, isNull);
      expect(p.reply, '모든 정보를 확인했어요!');
    });

    test('fromJson handles null fields', () {
      final p = ExtractedProfile.fromJson({'reply': ''});
      expect(p.name, isNull);
      expect(p.age, isNull);
    });

    test('isComplete true when all required fields present', () {
      final p = ExtractedProfile.fromJson(fullJson);
      expect(p.isComplete, true);
    });

    test('isComplete false when name missing', () {
      final p = ExtractedProfile.fromJson({...fullJson, 'name': null});
      expect(p.isComplete, false);
    });

    test('isComplete false when goal missing', () {
      final p = ExtractedProfile.fromJson({...fullJson, 'goal': null});
      expect(p.isComplete, false);
    });

    test('fromJson converts age num to int', () {
      final p = ExtractedProfile.fromJson({...fullJson, 'age': 28.0});
      expect(p.age, 28);
      expect(p.age, isA<int>());
    });
  });

  group('FoodNutrition', () {
    final json = {
      'name': '현미밥',
      'category': '밥류',
      'kcal': 340.0,
      'carb_g': 73.0,
      'protein_g': 7.0,
      'fat_g': 2.0,
      'sodium_mg': 5.0,
      'sugar_g': 0.5,
      'sat_fat_g': 0.3,
      'cholesterol_mg': 0.0,
      'serving': '1공기(210g)',
    };

    test('fromJson parses all fields', () {
      final f = FoodNutrition.fromJson(json);
      expect(f.name, '현미밥');
      expect(f.category, '밥류');
      expect(f.kcal, 340.0);
      expect(f.carbG, 73.0);
      expect(f.proteinG, 7.0);
      expect(f.fatG, 2.0);
      expect(f.sodiumMg, 5.0);
      expect(f.serving, '1공기(210g)');
    });

    test('fromJson defaults missing fields to zero', () {
      final f = FoodNutrition.fromJson({'name': '테스트'});
      expect(f.kcal, 0.0);
      expect(f.carbG, 0.0);
      expect(f.category, '');
    });
  });

  group('ChatResponse', () {
    test('fromJson parses all fields', () {
      final json = {
        'answer': '닭가슴살을 추천드려요.',
        'sources': ['doc1', 'doc2'],
        'detected_foods': ['닭가슴살'],
      };
      final r = ChatResponse.fromJson(json);
      expect(r.answer, '닭가슴살을 추천드려요.');
      expect(r.sources.length, 2);
      expect(r.detectedFoods, ['닭가슴살']);
    });

    test('fromJson handles empty lists', () {
      final r = ChatResponse.fromJson({'answer': '', 'sources': [], 'detected_foods': []});
      expect(r.sources, isEmpty);
      expect(r.detectedFoods, isEmpty);
    });

    test('fromJson handles missing sources and detected_foods', () {
      final r = ChatResponse.fromJson({'answer': 'ok'});
      expect(r.sources, isEmpty);
      expect(r.detectedFoods, isEmpty);
    });
  });
}
