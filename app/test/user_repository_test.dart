import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/models/db_models.dart';
import 'package:nutrai/repositories/user_repository.dart';
import 'helpers/db_test_helper.dart';

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late UserRepository repo;
  setUp(() => repo = UserRepository());

  UserProfileEntity makeUser({String nickname = '테스트유저'}) {
    final now = DateTime.now().toIso8601String();
    return UserProfileEntity(
      nickname: nickname,
      gender: '남',
      age: 25,
      heightCm: 175.0,
      weightKg: 70.0,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('UserRepository - hasUser', () {
    test('returns false when no user', () async {
      expect(await repo.hasUser(), false);
    });

    test('returns true after createUser', () async {
      await repo.createUser(makeUser());
      expect(await repo.hasUser(), true);
    });
  });

  group('UserRepository - createUser', () {
    test('returns positive id', () async {
      final id = await repo.createUser(makeUser());
      expect(id, greaterThan(0));
    });

    test('creates distinct ids for different users', () async {
      final id1 = await repo.createUser(makeUser(nickname: 'user1'));
      final id2 = await repo.createUser(makeUser(nickname: 'user2'));
      expect(id1, isNot(id2));
    });
  });

  group('UserRepository - getUserById', () {
    test('returns null for nonexistent id', () async {
      expect(await repo.getUserById(9999), isNull);
    });

    test('returns correct user by id', () async {
      final id = await repo.createUser(makeUser(nickname: '홍길동'));
      final user = await repo.getUserById(id);
      expect(user, isNotNull);
      expect(user!.nickname, '홍길동');
    });

    test('roundtrips all fields', () async {
      final now = DateTime.now().toIso8601String();
      final original = UserProfileEntity(
        nickname: '김철수',
        gender: '여',
        age: 30,
        heightCm: 165.0,
        weightKg: 55.0,
        goal: '다이어트',
        allergy: '유제품',
        createdAt: now,
        updatedAt: now,
      );
      final id = await repo.createUser(original);
      final fetched = await repo.getUserById(id);
      expect(fetched!.gender, '여');
      expect(fetched.age, 30);
      expect(fetched.heightCm, 165.0);
      expect(fetched.goal, '다이어트');
      expect(fetched.allergy, '유제품');
    });
  });

  group('UserRepository - getFirstUser', () {
    test('returns null when no users', () async {
      expect(await repo.getFirstUser(), isNull);
    });

    test('returns first inserted user', () async {
      await repo.createUser(makeUser(nickname: '첫번째'));
      await repo.createUser(makeUser(nickname: '두번째'));
      final first = await repo.getFirstUser();
      expect(first!.nickname, '첫번째');
    });
  });

  group('UserRepository - updateUser', () {
    test('updates nickname', () async {
      final id = await repo.createUser(makeUser(nickname: '원래이름'));
      final user = await repo.getUserById(id);
      final updated = user!.copyWith(nickname: '새이름', updatedAt: DateTime.now().toIso8601String());
      await repo.updateUser(updated);
      final fetched = await repo.getUserById(id);
      expect(fetched!.nickname, '새이름');
    });

    test('does not affect other users', () async {
      final id1 = await repo.createUser(makeUser(nickname: 'user1'));
      final id2 = await repo.createUser(makeUser(nickname: 'user2'));
      final u1 = await repo.getUserById(id1);
      await repo.updateUser(u1!.copyWith(nickname: 'updated1', updatedAt: DateTime.now().toIso8601String()));
      final u2 = await repo.getUserById(id2);
      expect(u2!.nickname, 'user2');
    });
  });

  group('UserRepository - deleteUser', () {
    test('removes user by id', () async {
      final id = await repo.createUser(makeUser());
      await repo.deleteUser(id);
      expect(await repo.getUserById(id), isNull);
    });

    test('hasUser false after deleting only user', () async {
      final id = await repo.createUser(makeUser());
      await repo.deleteUser(id);
      expect(await repo.hasUser(), false);
    });
  });
}
