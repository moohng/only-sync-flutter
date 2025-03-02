import 'dart:io';
import 'package:intl/intl.dart';
import 'package:only_sync_flutter/core/storage/storage_engine.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';
import '../storage/storage_service.dart';

/// 媒体文件类型
enum MediaType { image, video }

/// 同步状态
enum SyncStatus { notSynced, syncing, synced, failed }

/// 媒体文件信息
class MediaFileInfo {
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

  MediaFileInfo({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modifiedTime,
    required this.createdTime,
    this.syncStatus = SyncStatus.notSynced,
    this.syncError,
    this.remotePath,
    this.thumbnailPath,
  });

  MediaFileInfo copyWith({
    SyncStatus? syncStatus,
    String? syncError,
    String? remotePath,
    String? thumbnailPath,
  }) {
    return MediaFileInfo(
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

  MediaManager({StorageService? storageService, String? remoteBasePath = '/only_sync'})
      : _storageService = storageService,
        _remoteBasePath = remoteBasePath;

  // 添加更新存储服务的方法
  void updateStorageService(StorageService? service, {String? remoteBasePath}) {
    _storageService = service;
    _remoteBasePath = remoteBasePath ?? '/media';
  }

  /// 缩略图缓存目录
  late final Directory _thumbnailCacheDir;
  static const int _thumbnailSize = 200; // 缩略图大小

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
  Future<List<MediaFileInfo>> getMediaFiles({
    required AssetPathEntity album,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      final List<MediaFileInfo> mediaFiles = [];

      for (final asset in assets) {
        mediaFiles.add(AssetEntityImageInfo(
          asset: asset,
          path: (await asset.file)?.path ?? '',
          name: asset.title ?? 'Unknown',
          type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
          size: await asset.originFile.then((file) => file?.lengthSync() ?? 0),
          modifiedTime: asset.modifiedDateTime,
          createdTime: asset.createDateTime,
        ));
      }

      return mediaFiles;
    } catch (e) {
      print('Get media files error: $e');
      return [];
    }
  }

  /// 扫描指定目录下的媒体文件
  Future<List<MediaFileInfo>> scanDirectory(
    String dirPath, {
    void Function(int current, int total)? onProgress,
    int? limit,
    int offset = 0,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      print('目录不存在: $dirPath');
      return [];
    }

    print('开始扫描目录: $dirPath');
    final List<MediaFileInfo> mediaFiles = [];
    List<FileSystemEntity> entities = [];

    try {
      entities = await dir.list(recursive: true).toList();
      print('找到实体数量: ${entities.length}');
    } catch (e) {
      print('列出目录内容失败: $e');
      return [];
    }

    final int totalFiles = entities.length;
    int processedFiles = 0;

    for (final entity in entities.skip(offset).take(limit ?? double.maxFinite.toInt())) {
      try {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase().replaceFirst('.', '');
          if (_isMediaFile(extension)) {
            print('处理媒体文件: ${entity.path}');
            final stat = await entity.stat();
            final thumbnailPath = await _generateThumbnail(entity.path, extension);

            mediaFiles.add(
              MediaFileInfo(
                path: entity.path,
                name: path.basename(entity.path),
                type: _getMediaType(extension),
                size: stat.size,
                modifiedTime: stat.modified,
                createdTime: stat.changed,
                thumbnailPath: thumbnailPath,
              ),
            );
          }
        }
      } catch (e) {
        print('处理文件失败: ${entity.path}, 错误: $e');
      }

      processedFiles++;
      onProgress?.call(processedFiles, totalFiles);
    }

    print('目录扫描完成: $dirPath, 找到媒体文件: ${mediaFiles.length}');
    return mediaFiles;
  }

  /// 生成缩略图
  Future<String?> _generateThumbnail(String filePath, String extension) async {
    // 只为图片生成缩略图
    if (!_imageExtensions.contains(extension)) {
      return null;
    }

    final thumbnailPath = '${_thumbnailCacheDir.path}/${path.basename(filePath)}.thumb.jpg';

    // 如果缩略图已存在，直接返回
    if (await File(thumbnailPath).exists()) {
      return thumbnailPath;
    }

    try {
      await FlutterImageCompress.compressAndGetFile(
        filePath,
        thumbnailPath,
        minWidth: _thumbnailSize,
        minHeight: _thumbnailSize,
        quality: 85,
      );
      return thumbnailPath;
    } catch (e) {
      print('生成缩略图失败: $filePath, 错误: $e');
      return null;
    }
  }

  /// 清理缩略图缓存
  Future<void> clearThumbnailCache() async {
    if (await _thumbnailCacheDir.exists()) {
      await _thumbnailCacheDir.delete(recursive: true);
      await _thumbnailCacheDir.create();
    }
  }

  /// 同步单个文件
  Future<MediaFileInfo> syncFile(MediaFileInfo file) async {
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
  Future<List<MediaFileInfo>> syncFiles(List<MediaFileInfo> files) async {
    final results = <MediaFileInfo>[];
    for (final file in files) {
      results.add(await syncFile(file));
    }
    return results;
  }

  /// 判断文件是否为媒体文件
  bool _isMediaFile(String extension) {
    return _imageExtensions.contains(extension) || _videoExtensions.contains(extension);
  }

  /// 获取媒体类型
  MediaType _getMediaType(String extension) {
    if (_imageExtensions.contains(extension)) {
      return MediaType.image;
    }
    return MediaType.video;
  }

  /// 支持的图片格式
  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
  };

  /// 支持的视频格式
  static const _videoExtensions = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'm4v',
  };
}

class AssetEntityImageInfo extends MediaFileInfo {
  final AssetEntity asset;

  AssetEntityImageInfo({
    required this.asset,
    required String path,
    required String name,
    required MediaType type,
    required int size,
    required DateTime modifiedTime,
    required DateTime createdTime,
  }) : super(
          path: path,
          name: name,
          type: type,
          size: size,
          modifiedTime: modifiedTime,
          createdTime: createdTime,
        );
}
