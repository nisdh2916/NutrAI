import '../database/database_helper.dart';
import '../models/db_models.dart';

class FoodRepository {
  final _db = DatabaseHelper.instance;

  // ── 전체 음식 목록 ─────────────────────────────
  Future<List<FoodEntity>> getAllFoods() async {
    final db   = await _db.database;
    final rows = await db.query('food', orderBy: 'food_name ASC');
    return rows.map(FoodEntity.fromMap).toList();
  }

  // ── 음식 단건 조회 ─────────────────────────────
  Future<FoodEntity?> getFoodById(int id) async {
    final db   = await _db.database;
    final rows = await db.query('food', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return FoodEntity.fromMap(rows.first);
  }

  // ── 이름으로 검색 (LIKE) ───────────────────────
  Future<List<FoodEntity>> searchFoods(String query) async {
    if (query.trim().isEmpty) return getAllFoods();
    final db   = await _db.database;
    final rows = await db.query(
      'food',
      where: 'food_name LIKE ?',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'food_name ASC',
    );
    return rows.map(FoodEntity.fromMap).toList();
  }

  // ── 음식 생성 ──────────────────────────────────
  Future<int> createFood(FoodEntity food) async {
    final db  = await _db.database;
    final now = _db.nowIso();
    return db.insert('food', {
      ...food.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  // ── 음식 수정 ──────────────────────────────────
  Future<int> updateFood(FoodEntity food) async {
    final db = await _db.database;
    return db.update(
      'food',
      {...food.toMap(), 'updated_at': _db.nowIso()},
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  // ── 음식 삭제 ──────────────────────────────────
  Future<int> deleteFood(int id) async {
    final db = await _db.database;
    return db.delete('food', where: 'id = ?', whereArgs: [id]);
  }

  // ── 여러 id로 한번에 조회 ──────────────────────
  Future<List<FoodEntity>> getFoodsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db       = await _db.database;
    final placeholders = ids.map((_) => '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT * FROM food WHERE id IN ($placeholders)',
      ids,
    );
    return rows.map(FoodEntity.fromMap).toList();
  }
}
