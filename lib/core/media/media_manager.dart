import 'dart:io';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:only_sync_flutter/core/media/thumbnail_cache.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../storage/storage_service.dart';

/// 媒体文件类型
enum MediaType { image, video }

/// 同步状态
enum SyncStatus { notSynced, syncing, synced, failed }

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
  final String? thumbnailPath;

  AssetEntityImageInfo({
    required this.asset,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modifiedTime,
    required this.createdTime,
    required this.syncStatus,
    this.syncError,
    this.remotePath,
    this.thumbnailPath,
  });

  AssetEntityImageInfo copyWith({
    SyncStatus? syncStatus,
    String? syncError,
    String? remotePath,
    String? thumbnailPath,
  }) {
    return AssetEntityImageInfo(
      asset: asset,
      path: path,
      name: name,
      type: type,
      size: size,
      modifiedTime: modifiedTime,
      createdTime: createdTime,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      remotePath: remotePath ?? this.remotePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

/// 媒体管理器，负责扫描和管理本地媒体文件
class MediaManager {
  RemoteStorageService? _storageService;
  bool _hasPermission = false;
  final _syncCheckQueue = <String, AssetEntityImageInfo>{};
  bool _isCheckingSync = false;

  MediaManager({RemoteStorageService? storageService}) : _storageService = storageService;

  // 添加更新存储服务的方法
  void updateStorageService(RemoteStorageService? service) {
    _storageService = service;
  }

  /// 缩略图缓存目录
  late final Directory _thumbnailCacheDir;

  final _thumbnailCache = ThumbnailCache();
  static const thumbnailSize = ThumbnailSize(300, 300);

  /// 初始化缩略图缓存目录
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailCacheDir = Directory('${appDir.path}/thumbnails');
    if (!await _thumbnailCacheDir.exists()) {
      await _thumbnailCacheDir.create(recursive: true);
    }
    await _thumbnailCache.init();
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

  Future<String?> _generateAndCacheThumbnail(AssetEntity asset) async {
    // 先检查缓存
    final cachedPath = await _thumbnailCache.getThumbnailPath(asset.id, thumbnailSize.width, thumbnailSize.height);

    if (cachedPath != null) {
      return cachedPath;
    }

    // 生成新的缩略图
    final thumbnailBytes = await asset.thumbnailDataWithSize(
      thumbnailSize,
      quality: 95,
    );

    if (thumbnailBytes == null) return null;

    // 保存到缓存
    return _thumbnailCache.saveThumbnail(asset.id, thumbnailBytes, thumbnailSize.width, thumbnailSize.height);
  }

  /// 获取媒体文件
  Future<List<AssetEntityImageInfo>> getMediaFiles({
    required AssetPathEntity album,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      final List<AssetEntityImageInfo> mediaFiles = [];

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        // 获取或生成缩略图
        final thumbnailPath = await _generateAndCacheThumbnail(asset);

        final mediaFile = AssetEntityImageInfo(
          asset: asset,
          path: file.path,
          name: asset.title ?? 'Unknown',
          type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
          size: file.lengthSync(),
          modifiedTime: asset.modifiedDateTime,
          createdTime: asset.createDateTime,
          syncStatus: SyncStatus.notSynced,
          remotePath: null,
          thumbnailPath: thumbnailPath,
        );

        mediaFiles.add(mediaFile);

        // 添加到缩略图生成队列
        if (mediaFile.type == MediaType.image && mediaFile.thumbnailPath == null) {
          addToThumbnailQueue(mediaFile);
        }
        // 添加到同步检查队列
        _queueSyncCheck(mediaFile);
      }

      // 开始后台处理
      _startSyncCheck();
      _startThumbnailGeneration();

      return mediaFiles;
    } catch (e) {
      print('获取媒体文件失败: $e');
      return [];
    }
  }

  void _queueSyncCheck(AssetEntityImageInfo file) {
    _syncCheckQueue[file.path] = file;
  }

  Future<void> _startSyncCheck() async {
    if (_isCheckingSync || _syncCheckQueue.isEmpty || _storageService == null) return;

    _isCheckingSync = true;
    while (_syncCheckQueue.isNotEmpty) {
      try {
        final entry = _syncCheckQueue.entries.first;
        final file = entry.value;

        // 构建远程路径
        final dateStr = DateFormat('yyyy/MM').format(file.modifiedTime);
        final remotePath = '$dateStr/${file.name}';

        final exists = await _storageService!.checkFileExists(remotePath);
        if (exists) {
          // 通知UI更新
          onSyncStatusChanged?.call(file.copyWith(
            syncStatus: SyncStatus.synced,
            remotePath: remotePath,
          ));
        }

        _syncCheckQueue.remove(entry.key);
        // 添加小延迟避免过度占用资源
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('检查同步状态失败: $e');
        // 出错时也要移除，避免卡住队列
        if (_syncCheckQueue.isNotEmpty) {
          _syncCheckQueue.remove(_syncCheckQueue.keys.first);
        }
      }
    }
    _isCheckingSync = false;
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
      print('同步失败: $e');
      return file.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: e.toString(),
      );
    }
  }

  /// 同步多个文件
  Future<List<AssetEntityImageInfo>> syncFiles(List<AssetEntityImageInfo> files) async {
    final results = <AssetEntityImageInfo>[];
    for (final file in files) {
      results.add(await syncFile(file));
    }
    return results;
  }

  final _syncQueue = <String, AssetEntityImageInfo>{};
  final _thumbnailQueue = <String, AssetEntityImageInfo>{};
  bool _isSyncing = false;
  bool _isGeneratingThumbnails = false;

  // 启动后台同步
  Future<void> _startBackgroundSync() async {
    if (_isSyncing || _syncQueue.isEmpty || _storageService == null) return;

    _isSyncing = true;
    while (_syncQueue.isNotEmpty) {
      try {
        final entry = _syncQueue.entries.first;
        final file = entry.value;

        final result = await syncFile(file);
        onSyncStatusChanged?.call(result);

        _syncQueue.remove(entry.key);
        // 添加延迟避免占用过多资源
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('后台同步失败: $e');
        if (_syncQueue.isNotEmpty) {
          _syncQueue.remove(_syncQueue.keys.first);
        }
      }
    }
    _isSyncing = false;
  }

  // 生成缩略图
  Future<void> _startThumbnailGeneration() async {
    if (_isGeneratingThumbnails || _thumbnailQueue.isEmpty) return;

    _isGeneratingThumbnails = true;
    while (_thumbnailQueue.isNotEmpty) {
      try {
        final entry = _thumbnailQueue.entries.first;
        final file = entry.value;

        final thumbnailFile = await _generateThumbnail(file);
        if (thumbnailFile != null) {
          onSyncStatusChanged?.call(file.copyWith(thumbnailPath: thumbnailFile.path));
        }

        _thumbnailQueue.remove(entry.key);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        print('生成缩略图失败: $e');
        if (_thumbnailQueue.isNotEmpty) {
          _thumbnailQueue.remove(_thumbnailQueue.keys.first);
        }
      }
    }
    _isGeneratingThumbnails = false;
  }

  // 生成单个缩略图
  Future<File?> _generateThumbnail(AssetEntityImageInfo file) async {
    try {
      final thumbnailBytes = await file.asset.thumbnailDataWithSize(
        thumbnailSize,
        quality: 95,
      );

      if (thumbnailBytes == null) return null;

      final thumbnailPath = '${_thumbnailCacheDir.path}/${file.name}';
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return thumbnailFile;
    } catch (e) {
      print('生成缩略图失败: $e');
      return null;
    }
  }

  // 添加到缩略图生成队列
  void addToThumbnailQueue(AssetEntityImageInfo file) {
    _thumbnailQueue[file.path] = file;
    _startThumbnailGeneration();
  }

  // 保存每个相册的任务状态
  final _albumTasks = <String, Set<String>>{};

  void cancelTasks(String albumId) {
    if (_albumTasks.containsKey(albumId)) {
      // 取消该相册的所有同步任务
      final tasks = _albumTasks[albumId] ?? {};
      for (final taskId in tasks) {
        _syncQueue.removeWhere((key, value) => value.asset.id == taskId);
      }
      _albumTasks.remove(albumId);
    }
  }

  Future<void> addToSyncQueue(AssetEntityImageInfo file) async {
    // 生成任务ID
    final taskId = '${file.asset.id}_${DateTime.now().millisecondsSinceEpoch}';

    // 记录任务到相册
    final albumId = file.asset.relativePath ?? 'default';
    _albumTasks.putIfAbsent(albumId, () => {}).add(taskId);

    // 添加到同步队列
    _syncQueue.putIfAbsent(file.path, () => file);

    // _syncQueue[file.path] = file;
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
