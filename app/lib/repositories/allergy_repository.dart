import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/db_models.dart';

class AllergyRepository {
  final _db = DatabaseHelper.instance;

  Future<List<UserAllergyEntity>> getAllergies(int userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'local_user_allergy',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'allergy_name ASC',
    );
    return rows.map(UserAllergyEntity.fromMap).toList();
  }

  Future<void> addAllergy(UserAllergyEntity allergy) async {
    final db = await _db.database;
    await db.insert(
      'local_user_allergy',
      allergy.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // UNIQUE(user_id, allergy_code)
    );
  }

  Future<void> removeAllergy(int userId, String allergyCode) async {
    final db = await _db.database;
    await db.delete(
      'local_user_allergy',
      where: 'user_id = ? AND allergy_code = ?',
      whereArgs: [userId, allergyCode],
    );
  }

  Future<void> setAllergies(int userId, List<({String code, String name})> allergies) async {
    final db = await _db.database;
    final now = DatabaseHelper.instance.nowIso();
    await db.transaction((txn) async {
      await txn.delete('local_user_allergy', where: 'user_id = ?', whereArgs: [userId]);
      for (final a in allergies) {
        await txn.insert('local_user_allergy', {
          'user_id':      userId,
          'allergy_code': a.code,
          'allergy_name': a.name,
          'created_at':   now,
          'updated_at':   now,
        });
      }
    });
  }
}
