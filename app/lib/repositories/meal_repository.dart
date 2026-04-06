import '../database/database_helper.dart';
import '../models/db_models.dart';

class MealRepository {
  final _db = DatabaseHelper.instance;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // meal CRUD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 끼니 생성 → meal_id 반환
  Future<int> createMeal(MealEntity meal) async {
    final db  = await _db.database;
    final now = _db.nowIso();
    return db.insert('meal', {
      ...meal.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  /// meal_food 한 행 추가
  Future<int> addFoodToMeal(MealFoodEntity mf) async {
    final db  = await _db.database;
    final now = _db.nowIso();
    return db.insert('meal_food', {
      ...mf.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 끼니 + 음식 목록 한번에 저장 (트랜잭션)
  Future<int> saveMealWithFoods({
    required int userId,
    required String mealType,
    required DateTime eatenAt,
    String? memo,
    required List<({int foodId, double? amountG, double servingCount})> foods,
  }) async {
    final db  = await _db.database;
    final now = _db.nowIso();

    return db.transaction((txn) async {
      // 1) meal 삽입
      final mealId = await txn.insert('meal', {
        'user_id':    userId,
        'meal_type':  mealType,
        'eaten_at':   eatenAt.toIso8601String(),
        'memo':       memo,
        'created_at': now,
        'updated_at': now,
      });

      // 2) meal_food 삽입
      for (final f in foods) {
        await txn.insert('meal_food', {
          'meal_id':      mealId,
          'food_id':      f.foodId,
          'amount_g':     f.amountG,
          'serving_count':f.servingCount,
          'created_at':   now,
          'updated_at':   now,
        });
      }
      return mealId;
    });
  }

  /// 끼니 수정
  Future<int> updateMeal(MealEntity meal) async {
    final db = await _db.database;
    return db.update(
      'meal',
      {...meal.toMap(), 'updated_at': _db.nowIso()},
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  /// 끼니 삭제 (meal_food 연쇄 삭제 포함)
  Future<void> deleteMeal(int mealId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('meal_food', where: 'meal_id = ?', whereArgs: [mealId]);
      await txn.delete('meal',      where: 'id = ?',      whereArgs: [mealId]);
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 조회
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 특정 날짜의 모든 끼니 + 음식 (조인)
  Future<List<MealWithFoods>> getMealsForDate(int userId, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final db = await _db.database;

    // 해당 날짜 meal 목록
    final mealRows = await db.query(
      'meal',
      where: 'user_id = ? AND DATE(eaten_at) = ?',
      whereArgs: [userId, dateStr],
      orderBy: 'eaten_at ASC',
    );

    final result = <MealWithFoods>[];
    for (final mr in mealRows) {
      final meal      = MealEntity.fromMap(mr);
      final mfJoins   = await _getMealFoodJoins(db, meal.id!);
      result.add(MealWithFoods(meal: meal, foods: mfJoins));
    }
    return result;
  }

  /// 주간 (startDate ~ startDate+6일) 날짜별 끼니 합산 칼로리
  Future<Map<String, double>> getWeeklyKcal(int userId, DateTime startDate) async {
    final db  = await _db.database;
    final end = startDate.add(const Duration(days: 6));

    final rows = await db.rawQuery('''
      SELECT DATE(m.eaten_at) AS day, SUM(f.kcal * mf.serving_count) AS total
      FROM meal m
      JOIN meal_food mf ON mf.meal_id = m.id
      JOIN food f ON f.id = mf.food_id
      WHERE m.user_id = ?
        AND DATE(m.eaten_at) BETWEEN ? AND ?
      GROUP BY DATE(m.eaten_at)
    ''', [
      userId,
      _dateStr(startDate),
      _dateStr(end),
    ]);

    return {for (final r in rows) r['day'] as String: (r['total'] as num).toDouble()};
  }

  /// 월간 날짜별 끼니 합산 칼로리
  Future<Map<String, double>> getMonthlyKcal(int userId, int year, int month) async {
    final db = await _db.database;
    final ym = '${year}-${month.toString().padLeft(2, '0')}';

    final rows = await db.rawQuery('''
      SELECT DATE(m.eaten_at) AS day, SUM(f.kcal * mf.serving_count) AS total
      FROM meal m
      JOIN meal_food mf ON mf.meal_id = m.id
      JOIN food f ON f.id = mf.food_id
      WHERE m.user_id = ?
        AND strftime('%Y-%m', m.eaten_at) = ?
      GROUP BY DATE(m.eaten_at)
    ''', [userId, ym]);

    return {for (final r in rows) r['day'] as String: (r['total'] as num).toDouble()};
  }

  /// 오늘 날짜의 끼니 + 음식 전체 (홈 화면용)
  Future<List<MealWithFoods>> getTodayMeals(int userId) async {
    return getMealsForDate(userId, DateTime.now());
  }

  /// 날짜 범위 내 기록된 날짜 목록
  Future<List<String>> getRecordedDates(int userId, DateTime from, DateTime to) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT DATE(eaten_at) AS day
      FROM meal
      WHERE user_id = ?
        AND DATE(eaten_at) BETWEEN ? AND ?
      ORDER BY day ASC
    ''', [userId, _dateStr(from), _dateStr(to)]);
    return rows.map((r) => r['day'] as String).toList();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 내부 헬퍼
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<MealFoodJoin>> _getMealFoodJoins(dynamic db, int mealId) async {
    final rows = await db.rawQuery('''
      SELECT
        mf.id         AS mf_id,
        mf.meal_id    AS mf_meal_id,
        mf.food_id    AS mf_food_id,
        mf.amount_g   AS mf_amount_g,
        mf.serving_count AS mf_serving_count,
        mf.created_at AS mf_created_at,
        mf.updated_at AS mf_updated_at,
        f.id          AS f_id,
        f.food_no     AS f_food_no,
        f.food_name   AS f_food_name,
        f.kcal        AS f_kcal,
        f.carb_g      AS f_carb_g,
        f.protein_g   AS f_protein_g,
        f.fat_g       AS f_fat_g,
        f.created_at  AS f_created_at,
        f.updated_at  AS f_updated_at
      FROM meal_food mf
      JOIN food f ON f.id = mf.food_id
      WHERE mf.meal_id = ?
    ''', [mealId]);

    return rows.map((r) => MealFoodJoin(
      mealFood: MealFoodEntity.fromMap({
        'id':           r['mf_id'],
        'meal_id':      r['mf_meal_id'],
        'food_id':      r['mf_food_id'],
        'amount_g':     r['mf_amount_g'],
        'serving_count':r['mf_serving_count'],
        'created_at':   r['mf_created_at'],
        'updated_at':   r['mf_updated_at'],
      }),
      food: FoodEntity.fromMap({
        'id':         r['f_id'],
        'food_no':    r['f_food_no'],
        'food_name':  r['f_food_name'],
        'kcal':       r['f_kcal'],
        'carb_g':     r['f_carb_g'],
        'protein_g':  r['f_protein_g'],
        'fat_g':      r['f_fat_g'],
        'created_at': r['f_created_at'],
        'updated_at': r['f_updated_at'],
      }),
    )).toList();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
