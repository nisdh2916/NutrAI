import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/providers/user_state.dart';
import 'helpers/db_test_helper.dart';

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late UserState state;
  setUp(() => state = UserState());

  group('UserState - initial', () {
    test('user is null initially', () {
      expect(state.user, isNull);
    });

    test('userId is null initially', () {
      expect(state.userId, isNull);
    });
  });

  group('UserState - load', () {
    test('user stays null when DB empty', () async {
      await state.load();
      expect(state.user, isNull);
    });

    test('loads existing user after save', () async {
      await state.save(nickname: '홍길동', gender: '남', age: 28);
      final state2 = UserState();
      await state2.load();
      expect(state2.user!.nickname, '홍길동');
    });
  });

  group('UserState - save', () {
    test('creates user when user is null', () async {
      await state.save(nickname: '신규', gender: '여', age: 25);
      expect(state.user, isNotNull);
      expect(state.user!.nickname, '신규');
    });

    test('userId is set after save', () async {
      await state.save(nickname: '테스트');
      expect(state.userId, isNotNull);
      expect(state.userId, greaterThan(0));
    });

    test('updates existing user on second save', () async {
      await state.save(nickname: '원래이름');
      await state.save(nickname: '바뀐이름');
      expect(state.user!.nickname, '바뀐이름');
    });

    test('saves optional fields', () async {
      await state.save(
        nickname: '김철수',
        goal: '다이어트',
        allergy: '유제품',
        heightCm: 175.0,
        weightKg: 70.0,
      );
      expect(state.user!.goal, '다이어트');
      expect(state.user!.allergy, '유제품');
      expect(state.user!.heightCm, 175.0);
    });
  });

  group('UserState - clear', () {
    test('sets user to null', () async {
      await state.save(nickname: '테스트');
      state.clear();
      expect(state.user, isNull);
      expect(state.userId, isNull);
    });
  });
}
