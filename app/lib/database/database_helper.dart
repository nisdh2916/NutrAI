import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _dbName    = 'nutrai.db';
  static const _dbVersion = 1;

  // 싱글턴
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ── DB 초기화 ──────────────────────────────────
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // 외래키 활성화
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ── 테이블 생성 (NutrAi_LD.sql 기준) ────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        member_no      TEXT,
        nickname       TEXT NOT NULL,
        gender         TEXT,
        age            INTEGER,
        height_cm      REAL,
        weight_kg      REAL,
        activity_level TEXT,
        target_kcal    REAL,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        food_no    TEXT,
        food_name  TEXT NOT NULL,
        kcal       REAL NOT NULL DEFAULT 0,
        carb_g     REAL NOT NULL DEFAULT 0,
        protein_g  REAL NOT NULL DEFAULT 0,
        fat_g      REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meal (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_no    TEXT,
        user_id    INTEGER NOT NULL,
        meal_type  TEXT NOT NULL,
        eaten_at   TEXT NOT NULL,
        memo       TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_food (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id       INTEGER NOT NULL,
        food_id       INTEGER NOT NULL,
        amount_g      REAL,
        serving_count REAL DEFAULT 1,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        FOREIGN KEY (meal_id) REFERENCES meal(id),
        FOREIGN KEY (food_id) REFERENCES food(id)
      )
    ''');

    // 인덱스
    await db.execute('CREATE INDEX idx_meal_user_id ON meal(user_id)');
    await db.execute('CREATE INDEX idx_meal_eaten_at ON meal(eaten_at)');
    await db.execute('CREATE INDEX idx_meal_food_meal_id ON meal_food(meal_id)');
    await db.execute('CREATE INDEX idx_meal_food_food_id ON meal_food(food_id)');

    // 초기 샘플 데이터 삽입
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // 추후 마이그레이션 처리
  }

  // ── 샘플 데이터 (LD_Sample.sql 기준) ─────────────
  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // food 12개
    final foods = [
      {'id': 1,  'food_no': 'F001', 'food_name': '밥',         'kcal': 300.0, 'carb_g': 68.0, 'protein_g': 6.0,  'fat_g': 1.0},
      {'id': 2,  'food_no': 'F002', 'food_name': '계란후라이', 'kcal': 90.0,  'carb_g': 1.0,  'protein_g': 6.0,  'fat_g': 7.0},
      {'id': 3,  'food_no': 'F003', 'food_name': '김치',       'kcal': 20.0,  'carb_g': 4.0,  'protein_g': 1.0,  'fat_g': 0.0},
      {'id': 4,  'food_no': 'F004', 'food_name': '닭가슴살',   'kcal': 150.0, 'carb_g': 0.0,  'protein_g': 31.0, 'fat_g': 3.0},
      {'id': 5,  'food_no': 'F005', 'food_name': '샐러드',     'kcal': 80.0,  'carb_g': 10.0, 'protein_g': 2.0,  'fat_g': 3.0},
      {'id': 6,  'food_no': 'F006', 'food_name': '고구마',     'kcal': 130.0, 'carb_g': 31.0, 'protein_g': 2.0,  'fat_g': 0.0},
      {'id': 7,  'food_no': 'F007', 'food_name': '우유',       'kcal': 110.0, 'carb_g': 10.0, 'protein_g': 6.0,  'fat_g': 4.0},
      {'id': 8,  'food_no': 'F008', 'food_name': '바나나',     'kcal': 90.0,  'carb_g': 23.0, 'protein_g': 1.0,  'fat_g': 0.0},
      {'id': 9,  'food_no': 'F009', 'food_name': '두부',       'kcal': 80.0,  'carb_g': 3.0,  'protein_g': 8.0,  'fat_g': 5.0},
      {'id': 10, 'food_no': 'F010', 'food_name': '된장국',     'kcal': 60.0,  'carb_g': 6.0,  'protein_g': 4.0,  'fat_g': 2.0},
      {'id': 11, 'food_no': 'F011', 'food_name': '사과',       'kcal': 95.0,  'carb_g': 25.0, 'protein_g': 0.0,  'fat_g': 0.0},
      {'id': 12, 'food_no': 'F012', 'food_name': '요거트',     'kcal': 120.0, 'carb_g': 15.0, 'protein_g': 5.0,  'fat_g': 4.0},
    ];
    for (final f in foods) {
      await db.insert('food', {...f, 'created_at': now, 'updated_at': now});
    }
  }

  // ── 헬퍼 메서드 ───────────────────────────────
  String nowIso() => DateTime.now().toIso8601String();

  /// DB 전체 삭제 (개발용 리셋)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _db = null;
  }
}
