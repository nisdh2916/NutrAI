import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nutrai/database/database_helper.dart';

Future<void> setUpTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> resetTestDatabase() async {
  try {
    final db = await DatabaseHelper.instance.database;
    await db.close();
  } catch (_) {}
  await DatabaseHelper.instance.deleteDatabase();
}
