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

/// 同步状态
enum SyncStatus { notSynced, willSync, syncing, synced, failed }

/// 媒体文件信息
class AssetEntityImageInfo {
  final AssetEntity asset;
  final SyncStatus syncStatus;
  final String? syncError;
  final String? remotePath;
  final Future<Uint8List?> thumbnail;

  AssetEntityImageInfo({
    required this.asset,
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
    int pageSize = 40,
  }) async {
    try {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      log('获取到 ${assets.length} 个媒体文件');

      if (_storageService == null || _storageService?.id == null) {
        return assets
            .map((e) => AssetEntityImageInfo(
                  asset: e,
                  syncStatus: SyncStatus.notSynced,
                  remotePath: null,
                  thumbnail: thumbCache.getThumb(e),
                ))
            .toList();
      }

      final List<AssetEntityImageInfo> mediaFiles = [];
      // 调试数据库表结构
      await _mediaDao.dbHelper.debugCheckTable();
      // 批量查询数据库
      final cachedInfoMap = await _mediaDao.batchGetFileInfo(assets.map((e) => e.id).toList(), _storageService?.id);

      for (final asset in assets) {
        if (cachedInfoMap.containsKey(asset.id)) {
          mediaFiles.add(
              cachedInfoMap[asset.id]!.toAssetEntityImageInfo(asset: asset, thumbnail: thumbCache.getThumb(asset)));
          continue;
        }

        final mediaFile = AssetEntityImageInfo(
          asset: asset,
          syncStatus: SyncStatus.notSynced,
          remotePath: null,
          thumbnail: thumbCache.getThumb(asset),
        );

        mediaFiles.add(mediaFile);
      }

      // 批量保存新记录
      if (mediaFiles.isNotEmpty) {
        Future.wait(mediaFiles
            .where((f) => !cachedInfoMap.containsKey(f.asset.id))
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
  Future<AssetEntityImageInfo> syncFile(AssetEntityImageInfo imgInfo) async {
    if (_storageService == null) {
      return imgInfo.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: '存储服务未初始化',
      );
    }

    try {
      // 创建按年月组织的远程路径
      final dateStr = DateFormat('yyyy/MM').format(imgInfo.asset.modifiedDateTime);
      final remotePath = '$dateStr/${imgInfo.asset.title ?? 'Unknown'}';

      // 检查文件是否已经同步
      if (await _storageService!.checkFileExists(remotePath)) {
        return imgInfo.copyWith(
          syncStatus: SyncStatus.synced,
          remotePath: remotePath,
        );
      }

      // 上传文件
      await _storageService!.uploadFile((await imgInfo.asset.file)!.path, remotePath);

      return imgInfo.copyWith(
        syncStatus: SyncStatus.synced,
        syncError: null,
        remotePath: remotePath,
      );
    } catch (e) {
      log('同步失败: $e');
      return imgInfo.copyWith(
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
        final imgInfo = entry.value;

        onSyncStatusChanged?.call(imgInfo.copyWith(syncStatus: SyncStatus.syncing));
        final result = await syncFile(imgInfo);
        await _mediaDao.updateSyncStatus(
          (await imgInfo.asset.file)!.path,
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

  Future<void> addToSyncQueue(AssetEntityImageInfo imgInfo) async {
    onSyncStatusChanged?.call(imgInfo.copyWith(syncStatus: SyncStatus.willSync));

    // 添加到同步队列
    _syncQueue.putIfAbsent((await imgInfo.asset.file)!.path, () => imgInfo);

    _startBackgroundSync();
  }
}

class SyncTask {
  final String id;
  final AssetEntityImageInfo imgInfo;
  final VoidCallback? onComplete;

  SyncTask({
    required this.id,
    required this.imgInfo,
    this.onComplete,
  });
}
