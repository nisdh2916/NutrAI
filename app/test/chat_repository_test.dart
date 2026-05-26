import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/repositories/chat_repository.dart';
import 'helpers/db_test_helper.dart';

void main() {
  setUpAll(setUpTestDatabase);
  setUp(resetTestDatabase);

  late ChatRepository repo;
  setUp(() => repo = ChatRepository());

  group('ChatRepository - insert & getLast30Days', () {
    test('getLast30Days returns empty list initially', () async {
      expect(await repo.getLast30Days(), isEmpty);
    });

    test('inserted message appears in getLast30Days', () async {
      await repo.insert('user', '안녕하세요');
      final msgs = await repo.getLast30Days();
      expect(msgs.length, 1);
      expect(msgs.first.role, 'user');
      expect(msgs.first.text, '안녕하세요');
    });

    test('multiple messages ordered by created_at', () async {
      await repo.insert('user', '첫 메시지');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.insert('bot', '답변');
      final msgs = await repo.getLast30Days();
      expect(msgs.length, 2);
      expect(msgs[0].role, 'user');
      expect(msgs[1].role, 'bot');
    });

    test('message has non-null id after insert', () async {
      await repo.insert('bot', '안녕');
      final msgs = await repo.getLast30Days();
      expect(msgs.first.id, isNotNull);
    });
  });

  group('ChatRepository - clearAll', () {
    test('removes all messages', () async {
      await repo.insert('user', '메시지1');
      await repo.insert('bot', '메시지2');
      await repo.clearAll();
      expect(await repo.getLast30Days(), isEmpty);
    });

    test('clearAll on empty table does not throw', () async {
      await expectLater(repo.clearAll(), completes);
    });
  });

  group('ChatRepository - deleteOlderThan30Days', () {
    test('does not delete recent messages', () async {
      await repo.insert('user', '최근 메시지');
      await repo.deleteOlderThan30Days();
      expect(await repo.getLast30Days(), hasLength(1));
    });
  });
}
