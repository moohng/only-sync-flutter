import 'dart:developer';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';
import '../media/media_manager.dart';
import 'database_helper.dart';

const String mediaFilesTable = 'media_files';

class MediaDRO {
  final SyncStatus syncStatus;
  final String? syncError;
  final String? remotePath;

  MediaDRO({
    required this.syncStatus,
    this.syncError,
    this.remotePath,
  });

  toAssetEntityImageInfo({required AssetEntity asset, required Future<Uint8List?> thumbnail}) {
    return AssetEntityImageInfo(
      asset: asset,
      syncStatus: syncStatus,
      syncError: syncError,
      remotePath: remotePath,
      thumbnail: thumbnail,
    );
  }

  static fromMap(Map<String, dynamic> map) {
    return MediaDRO(
      syncStatus: SyncStatus.values[map['sync_status'] as int],
      syncError: map['sync_error'] as String?,
      remotePath: map['remote_path'] as String?,
    );
  }
}

class MediaDao {
  final dbHelper = DatabaseHelper();

  Future<int> insertOrUpdate(AssetEntityImageInfo file, String? accountId) async {
    final db = await dbHelper.database;

    final data = {
      'id': file.asset.id,
      'sync_status': file.syncStatus.index,
      'sync_error': file.syncError,
      'remote_path': file.remotePath,
      'account_id': accountId,
      'last_sync_time': DateTime.now().millisecondsSinceEpoch,
    };

    log('准备插入数据: $data');

    final id = await db.insert(
      mediaFilesTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    log('插入结果ID: $id');
    return id;
  }

  Future<MediaDRO?> getFileInfo(String id, String? accountId) async {
    final db = await dbHelper.database;
    log('查询参数 - id: $id, accountId: $accountId');

    // 先查询所有数据，看看数据库中是否有数据
    final allData = await db.query(mediaFilesTable);
    log('数据库中所有数据: ${allData.length}条');

    final List<Map<String, dynamic>> maps = await db.query(
      mediaFilesTable,
      where: accountId == null ? 'id = ? AND account_id IS NULL' : 'id = ? AND account_id = ?',
      whereArgs: accountId == null ? [id] : [id, accountId],
    );

    log('查询SQL: SELECT * FROM $mediaFilesTable WHERE id = "$id" AND account_id = "$accountId"');
    log('查询结果: ${maps.length}条');
    if (!maps.isEmpty) {
      log('首条数据: ${maps.first}');
    }

    if (maps.isEmpty) return null;

    return MediaDRO(
      syncStatus: SyncStatus.values[maps.first['sync_status'] as int],
      syncError: maps.first['sync_error'] as String?,
      remotePath: maps.first['remote_path'] as String?,
    );
  }

  Future<Map<String, MediaDRO>> batchGetFileInfo(List<String> ids, String? accountId) async {
    final db = await dbHelper.database;

    // 构建 IN 查询条件
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      mediaFilesTable,
      where: accountId == null
          ? 'id IN ($placeholders) AND account_id IS NULL'
          : 'id IN ($placeholders) AND account_id = ?',
      whereArgs: accountId == null ? ids : [...ids, accountId],
    );

    log('批量查询 ${ids.length} 个文件');
    log('查询结果: ${maps.length}条');

    // 将结果转换为 Map
    return Map.fromEntries(
      maps.map((map) => MapEntry(
            map['id'] as String,
            MediaDRO.fromMap(map),
          )),
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status, String? error, String? remotePath) async {
    final db = await dbHelper.database;
    await db.update(
      mediaFilesTable,
      {
        'sync_status': status.index,
        'sync_error': error,
        'remote_path': remotePath,
        'last_sync_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAccountData(String accountId) async {
    final db = await dbHelper.database;
    await db.delete(
      mediaFilesTable,
      where: '"account_id" = ?',
      whereArgs: [accountId],
    );
  }
}
