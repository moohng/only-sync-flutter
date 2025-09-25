import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:only_sync_flutter/core/database/media_dao.dart';
import 'package:only_sync_flutter/core/media/lru_thumb_cache.dart';
import 'package:only_sync_flutter/core/store/sync_status_store.dart';
import 'package:photo_manager/photo_manager.dart';
import '../storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 媒体文件类型
enum MediaType { image, video }

/// 同步状态
enum SyncStatus { notSynced, willSync, syncing, synced, failed }

/// 媒体文件信息
class AssetEntityImageInfo {
  final AssetEntity asset;
  final String path;
  final String name;
  final MediaType type;
  final int size;
  final DateTime modifiedTime;
  final DateTime createdTime;
  final SyncStatus syncStatus;
  final String? syncError;
  final String? remotePath;
  final Future<Uint8List?> thumbnail;

  AssetEntityImageInfo({
    required this.asset,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modifiedTime,
    required this.createdTime,
    required this.syncStatus,
    required this.thumbnail,
    this.syncError,
    this.remotePath,
  });

  AssetEntityImageInfo copyWith({
    SyncStatus? syncStatus,
    String? syncError,
    String? remotePath,
  }) {
    return AssetEntityImageInfo(
      asset: asset,
      path: path,
      name: name,
      type: type,
      size: size,
      modifiedTime: modifiedTime,
      createdTime: createdTime,
      thumbnail: thumbnail,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      remotePath: remotePath ?? this.remotePath,
    );
  }
}

/// 媒体管理器，负责扫描和管理本地媒体文件
class MediaManager {
  final MediaDao _mediaDao = MediaDao();
  final SyncStatusStore _syncStore = SyncStatusStore();
  RemoteStorageService? _storageService;
  bool _hasPermission = false;

  final thumbCache = LruThumbCache(capacity: 300);

  MediaManager({RemoteStorageService? storageService}) : _storageService = storageService;

  // 添加更新存储服务的方法
  void updateStorageService(RemoteStorageService? service) {
    _storageService = service;
    // 切换账户时更新同步状态存储
    if (service != null) {
      _syncStore.switchAccount(service.id!);
    } else {
      _syncStore.clear();
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString('activeAccount');
    await _syncStore.init(activeId);
  }

  /// 请求权限
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    _hasPermission = result.isAuth;
    return _hasPermission;
  }

  /// 获取相册列表
  Future<List<AssetPathEntity>> getAlbums() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }
    return PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );
  }

  /// 获取媒体文件
  Future<List<AssetEntityImageInfo>> getMediaFiles({
    required AssetPathEntity album,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      // 调试数据库表结构
      await _mediaDao.dbHelper.debugCheckTable();

      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      log('获取到 ${assets.length} 个媒体文件');

      final List<AssetEntityImageInfo> mediaFiles = [];
      final List<String> paths = [];
      final Map<String, AssetEntity> assetMap = {};

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;
        paths.add(file.path);
        assetMap[file.path] = asset;
      }

      // 批量查询数据库
      final cachedInfoMap = await _mediaDao.batchGetFileInfo(paths, _storageService?.id);

      for (final path in paths) {
        final asset = assetMap[path]!;
        final file = await asset.file;

        if (cachedInfoMap.containsKey(path)) {
          mediaFiles
              .add(cachedInfoMap[path]!.toAssetEntityImageInfo(asset: asset, thumbnail: thumbCache.getThumb(asset)));
          continue;
        }

        final mediaFile = AssetEntityImageInfo(
          asset: asset,
          path: file!.path,
          name: asset.title ?? 'Unknown',
          type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
          size: file.lengthSync(),
          modifiedTime: asset.modifiedDateTime,
          createdTime: asset.createDateTime,
          syncStatus: SyncStatus.notSynced,
          remotePath: null,
          thumbnail: thumbCache.getThumb(asset),
        );

        mediaFiles.add(mediaFile);
      }

      // 批量保存新记录
      if (mediaFiles.isNotEmpty) {
        await Future.wait(mediaFiles
            .where((f) => !cachedInfoMap.containsKey(f.path))
            .map((f) => _mediaDao.insertOrUpdate(f, _storageService?.id)));
      }

      return mediaFiles;
    } catch (e) {
      log('获取媒体文件失败: $e');
      return [];
    }
  }

  // 添加状态变化回调
  void Function(AssetEntityImageInfo file)? onSyncStatusChanged;

  /// 同步单个文件
  Future<AssetEntityImageInfo> syncFile(AssetEntityImageInfo file) async {
    if (_storageService == null) {
      return file.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: '存储服务未初始化',
      );
    }

    try {
      // 创建按年月组织的远程路径
      final dateStr = DateFormat('yyyy/MM').format(file.modifiedTime);
      final remotePath = '$dateStr/${file.name}';

      // 检查文件是否已经同步
      if (await _storageService!.checkFileExists(remotePath)) {
        return file.copyWith(
          syncStatus: SyncStatus.synced,
          remotePath: remotePath,
        );
      }

      // 上传文件
      await _storageService!.uploadFile(file.path, remotePath);

      return file.copyWith(
        syncStatus: SyncStatus.synced,
        syncError: null,
        remotePath: remotePath,
      );
    } catch (e) {
      log('同步失败: $e');
      return file.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: e.toString(),
      );
    }
  }

  final _syncQueue = <String, AssetEntityImageInfo>{};
  bool _isSyncing = false;

  // 启动后台同步
  Future<void> _startBackgroundSync() async {
    if (_isSyncing || _syncQueue.isEmpty || _storageService == null) return;

    _isSyncing = true;
    while (_syncQueue.isNotEmpty) {
      try {
        final entry = _syncQueue.entries.first;
        final file = entry.value;

        onSyncStatusChanged?.call(file.copyWith(syncStatus: SyncStatus.syncing));
        final result = await syncFile(file);
        await _mediaDao.updateSyncStatus(
          file.path,
          result.syncStatus,
          result.syncError,
          result.remotePath,
        );
        onSyncStatusChanged?.call(result);

        if (result.syncStatus == SyncStatus.synced) {
          _syncQueue.remove(entry.key);
        }
        // 添加延迟避免占用过多资源
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        log('后台同步失败: $e');
        if (_syncQueue.isNotEmpty) {
          _syncQueue.remove(_syncQueue.keys.first);
        }
      }
    }
    _isSyncing = false;
  }

  Future<void> addToSyncQueue(AssetEntityImageInfo file) async {
    onSyncStatusChanged?.call(file.copyWith(syncStatus: SyncStatus.willSync));

    // 添加到同步队列
    _syncQueue.putIfAbsent(file.path, () => file);

    _startBackgroundSync();
  }
}

class SyncTask {
  final String id;
  final AssetEntityImageInfo file;
  final VoidCallback? onComplete;

  SyncTask({
    required this.id,
    required this.file,
    this.onComplete,
  });
}
