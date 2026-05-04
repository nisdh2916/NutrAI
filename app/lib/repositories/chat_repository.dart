import '../database/database_helper.dart';

class ChatMessageEntity {
  final int? id;
  final String role; // 'user' | 'bot'
  final String text;
  final String createdAt;

  const ChatMessageEntity({
    this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageEntity.fromMap(Map<String, dynamic> m) => ChatMessageEntity(
    id: m['id'] as int?,
    role: m['role'] as String,
    text: m['text'] as String,
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'role': role,
    'text': text,
    'created_at': createdAt,
  };
}

class ChatRepository {
  final _db = DatabaseHelper.instance;

  Future<List<ChatMessageEntity>> getLast30Days() async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final rows = await db.query(
      'chat_message',
      where: 'created_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessageEntity.fromMap).toList();
  }

  Future<void> insert(String role, String text) async {
    final db = await _db.database;
    await db.insert('chat_message', {
      'role': role,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('chat_message');
  }

  Future<void> deleteOlderThan30Days() async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete('chat_message', where: 'created_at < ?', whereArgs: [cutoff]);
  }
}
