import 'dart:developer';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';
import '../media/media_manager.dart';
import 'database_helper.dart';

const String mediaFilesTable = 'media_files';

class MediaDRO {
  final String path;
  final String name;
  final MediaType type;
  final int size;
  final DateTime modifiedTime;
  final DateTime createdTime;
  final SyncStatus syncStatus;
  final String? syncError;
  final String? remotePath;
  // final String? thumbnailPath;

  MediaDRO({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modifiedTime,
    required this.createdTime,
    required this.syncStatus,
    this.syncError,
    this.remotePath,
    // this.thumbnailPath,
  });

  toAssetEntityImageInfo({required AssetEntity asset, required Future<Uint8List?> thumbnail}) {
    return AssetEntityImageInfo(
      asset: asset,
      path: path,
      name: name,
      type: type,
      size: size,
      modifiedTime: modifiedTime,
      createdTime: createdTime,
      syncStatus: syncStatus,
      syncError: syncError,
      remotePath: remotePath,
      thumbnail: thumbnail,
      // thumbnailPath: thumbnailPath,
    );
  }

  static fromMap(Map<String, dynamic> map) {
    return MediaDRO(
      path: map['path'] as String,
      name: map['name'] as String,
      type: MediaType.values[map['type'] as int],
      size: map['size'] as int,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(map['modified_time'] as int),
      createdTime: DateTime.fromMillisecondsSinceEpoch(map['created_time'] as int),
      syncStatus: SyncStatus.values[map['sync_status'] as int],
      syncError: map['sync_error'] as String?,
      remotePath: map['remote_path'] as String?,
      // thumbnailPath: map['thumbnail_path'] as String?,
    );
  }
}

class MediaDao {
  final dbHelper = DatabaseHelper();

  Future<int> insertOrUpdate(AssetEntityImageInfo file, String? accountId) async {
    final db = await dbHelper.database;

    final data = {
      'id': file.asset.id,
      'path': file.path,
      'name': file.name,
      'type': file.type.index,
      'size': file.size,
      'modified_time': file.modifiedTime.millisecondsSinceEpoch,
      'created_time': file.createdTime.millisecondsSinceEpoch,
      'sync_status': file.syncStatus.index,
      'sync_error': file.syncError,
      'remote_path': file.remotePath,
      // 'thumbnail_path': file.thumbnailPath,
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

  Future<MediaDRO?> getFileInfo(String path, String? accountId) async {
    final db = await dbHelper.database;
    log('查询参数 - path: $path, accountId: $accountId');

    // 先查询所有数据，看看数据库中是否有数据
    final allData = await db.query(mediaFilesTable);
    log('数据库中所有数据: ${allData.length}条');

    final List<Map<String, dynamic>> maps = await db.query(
      mediaFilesTable,
      where: accountId == null ? 'path = ? AND account_id IS NULL' : 'path = ? AND account_id = ?',
      whereArgs: accountId == null ? [path] : [path, accountId],
    );

    log('查询SQL: SELECT * FROM $mediaFilesTable WHERE path = "$path" AND account_id = "$accountId"');
    log('查询结果: ${maps.length}条');
    if (!maps.isEmpty) {
      log('首条数据: ${maps.first}');
    }

    if (maps.isEmpty) return null;

    return MediaDRO(
      path: maps.first['path'] as String,
      name: maps.first['name'] as String,
      type: MediaType.values[maps.first['type'] as int],
      size: maps.first['size'] as int,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(maps.first['modified_time'] as int),
      createdTime: DateTime.fromMillisecondsSinceEpoch(maps.first['created_time'] as int),
      syncStatus: SyncStatus.values[maps.first['sync_status'] as int],
      syncError: maps.first['sync_error'] as String?,
      remotePath: maps.first['remote_path'] as String?,
      // thumbnailPath: maps.first['thumbnail_path'] as String?,
    );
  }

  Future<Map<String, MediaDRO>> batchGetFileInfo(List<String> paths, String? accountId) async {
    final db = await dbHelper.database;

    // 构建 IN 查询条件
    final placeholders = List.filled(paths.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      mediaFilesTable,
      where: accountId == null
          ? 'path IN ($placeholders) AND account_id IS NULL'
          : 'path IN ($placeholders) AND account_id = ?',
      whereArgs: accountId == null ? paths : [...paths, accountId],
    );

    log('批量查询 ${paths.length} 个文件');
    log('查询结果: ${maps.length}条');

    // 将结果转换为 Map
    return Map.fromEntries(
      maps.map((map) => MapEntry(
            map['path'] as String,
            MediaDRO.fromMap(map),
          )),
    );
  }

  Future<void> updateSyncStatus(String path, SyncStatus status, String? error, String? remotePath) async {
    final db = await dbHelper.database;
    await db.update(
      mediaFilesTable,
      {
        'sync_status': status.index,
        'sync_error': error,
        'remote_path': remotePath,
        'last_sync_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> updateThumbnailPath(String path, String thumbnailPath) async {
    final db = await dbHelper.database;
    await db.update(
      mediaFilesTable,
      {'thumbnail_path': thumbnailPath},
      where: '"path" = ?',
      whereArgs: [path],
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
