import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'media_sync.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    log('创建数据库表...');
    await db.execute('''
      CREATE TABLE media_files (
        id TEXT PRIMARY KEY,
        sync_status INTEGER NOT NULL,
        sync_error TEXT,
        remote_path TEXT,
        account_id TEXT,
        last_sync_time INTEGER
      )
    ''');
    log('数据库表创建完成');

    // 创建索引
    await db.execute('CREATE INDEX idx_account ON media_files(account_id)');
  }

  // 添加一个用于调试的方法
  Future<void> debugCheckTable() async {
    final db = await database;
    final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
    log('数据库中的表: ${tables.map((e) => e['name'])}');

    final tableInfo = await db.rawQuery('PRAGMA table_info(media_files)');
    log('表结构: $tableInfo');
  }
}
