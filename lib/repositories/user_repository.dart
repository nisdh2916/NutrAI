import '../database/database_helper.dart';
import '../models/db_models.dart';

class UserRepository {
  final _db = DatabaseHelper.instance;

  // ── 사용자 생성 ────────────────────────────────
  Future<int> createUser(UserProfileEntity user) async {
    final db  = await _db.database;
    final now = _db.nowIso();
    return db.insert('user_profile', {
      ...user.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  // ── 사용자 조회 (id) ───────────────────────────
  Future<UserProfileEntity?> getUserById(int id) async {
    final db   = await _db.database;
    final rows = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfileEntity.fromMap(rows.first);
  }

  // ── 첫 번째 사용자 조회 (단일 사용자 앱) ────────
  Future<UserProfileEntity?> getFirstUser() async {
    final db   = await _db.database;
    final rows = await db.query('user_profile', limit: 1, orderBy: 'id ASC');
    if (rows.isEmpty) return null;
    return UserProfileEntity.fromMap(rows.first);
  }

  // ── 사용자 수정 ────────────────────────────────
  Future<int> updateUser(UserProfileEntity user) async {
    final db  = await _db.database;
    return db.update(
      'user_profile',
      {...user.toMap(), 'updated_at': _db.nowIso()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // ── 사용자 존재 여부 ───────────────────────────
  Future<bool> hasUser() async {
    final db   = await _db.database;
    final rows = await db.query('user_profile', limit: 1);
    return rows.isNotEmpty;
  }

  // ── 사용자 삭제 ────────────────────────────────
  Future<int> deleteUser(int id) async {
    final db = await _db.database;
    return db.delete('user_profile', where: 'id = ?', whereArgs: [id]);
  }
}
