import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/providers/app_state.dart';
import 'helpers/db_test_helper.dart';

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late AppState state;
  setUp(() => state = AppState());

  group('AppState - initial state', () {
    test('user is null before init', () {
      expect(state.user, isNull);
    });

    test('loading is false before init', () {
      expect(state.loading, false);
    });

    test('todayMeals is empty before init', () {
      expect(state.todayMeals, isEmpty);
    });

    test('todayKcal is zero before init', () {
      expect(state.todayKcal, 0.0);
    });
  });

  group('AppState - init', () {
    test('loading becomes false after init', () async {
      await state.init();
      expect(state.loading, false);
    });

    test('user stays null when DB empty', () async {
      await state.init();
      expect(state.user, isNull);
    });

    test('loads user if one exists', () async {
      final state2 = AppState();
      await state2.saveUser(nickname: '기존유저');
      final state3 = AppState();
      await state3.init();
      expect(state3.user!.nickname, '기존유저');
    });
  });

  group('AppState - saveUser', () {
    test('creates user when none exists', () async {
      await state.saveUser(nickname: '홍길동', gender: '남', age: 25);
      expect(state.user, isNotNull);
      expect(state.user!.nickname, '홍길동');
    });

    test('userId is assigned after saveUser', () async {
      await state.saveUser(nickname: '테스트');
      expect(state.userId, isNotNull);
      expect(state.userId, greaterThan(0));
    });

    test('saves all optional profile fields', () async {
      await state.saveUser(
        nickname: '김철수',
        gender: '여',
        age: 30,
        heightCm: 160.0,
        weightKg: 55.0,
        goal: '다이어트',
        allergy: '유제품',
        activityLevel: '보통',
      );
      expect(state.user!.goal, '다이어트');
      expect(state.user!.allergy, '유제품');
      expect(state.user!.heightCm, 160.0);
    });

    test('updates existing user on second call', () async {
      await state.saveUser(nickname: '원래이름');
      await state.saveUser(nickname: '바뀐이름');
      expect(state.user!.nickname, '바뀐이름');
    });
  });

  group('AppState - getOrCreateFood', () {
    test('creates food and returns id', () async {
      await state.saveUser(nickname: '테스트');
      final id = await state.getOrCreateFood(
        name: '새음식', kcal: 200.0, carbG: 30.0, proteinG: 10.0, fatG: 5.0,
      );
      expect(id, greaterThan(0));
    });

    test('same name returns same id', () async {
      await state.saveUser(nickname: '테스트');
      final id1 = await state.getOrCreateFood(
        name: '중복음식', kcal: 100.0, carbG: 10.0, proteinG: 5.0, fatG: 2.0,
      );
      final id2 = await state.getOrCreateFood(
        name: '중복음식', kcal: 100.0, carbG: 10.0, proteinG: 5.0, fatG: 2.0,
      );
      expect(id1, id2);
    });
  });

  group('AppState - resetUser', () {
    test('clears user after reset', () async {
      await state.saveUser(nickname: '삭제예정');
      await state.resetUser();
      expect(state.user, isNull);
    });

    test('loading is false after reset', () async {
      await state.saveUser(nickname: '삭제예정');
      await state.resetUser();
      expect(state.loading, false);
    });

    test('todayMeals empty after reset', () async {
      await state.saveUser(nickname: '테스트');
      await state.resetUser();
      expect(state.todayMeals, isEmpty);
    });
  });
}
