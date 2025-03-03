import 'dart:io';
import 'package:intl/intl.dart';
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
  StorageService? _storageService;
  String? _remoteBasePath;
  bool _hasPermission = false;
  final _syncCheckQueue = <String, AssetEntityImageInfo>{};
  bool _isCheckingSync = false;

  MediaManager({StorageService? storageService, String? remoteBasePath = '/only_sync'})
      : _storageService = storageService,
        _remoteBasePath = remoteBasePath;

  // 添加更新存储服务的方法
  void updateStorageService(StorageService? service, {String? remoteBasePath}) {
    _storageService = service;
    _remoteBasePath = remoteBasePath ?? _remoteBasePath;
  }

  /// 缩略图缓存目录
  late final Directory _thumbnailCacheDir;

  /// 初始化缩略图缓存目录
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailCacheDir = Directory('${appDir.path}/thumbnails');
    if (!await _thumbnailCacheDir.exists()) {
      await _thumbnailCacheDir.create(recursive: true);
    }
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
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      final List<AssetEntityImageInfo> mediaFiles = [];

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

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
        );

        mediaFiles.add(mediaFile);
        // 加入检查队列
        _queueSyncCheck(mediaFile);
      }

      // 开始后台检查
      _startSyncCheck();

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
        final remotePath = '$_remoteBasePath/$dateStr/${file.name}';

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
    if (_storageService == null || _remoteBasePath == null) {
      return file.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: '存储服务未初始化',
      );
    }

    try {
      // 创建按年月组织的远程路径
      final dateStr = DateFormat('yyyy/MM').format(file.modifiedTime);
      final remotePath = '$_remoteBasePath/$dateStr/${file.name}';

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
}
