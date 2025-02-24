import 'dart:io';
import 'package:only_sync_flutter/core/storage/storage_engine.dart';

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
  });

  MediaFileInfo copyWith({
    SyncStatus? syncStatus,
    String? syncError,
    String? remotePath,
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
    );
  }
}

/// 媒体管理器，负责扫描和管理本地媒体文件
class MediaManager {
  final StorageEngine? _storageEngine;
  final String? _remoteBasePath;

  MediaManager({StorageEngine? storageEngine, String? remoteBasePath})
      : _storageEngine = storageEngine,
        _remoteBasePath = remoteBasePath;

  /// 扫描指定目录下的媒体文件
  Future<List<MediaFileInfo>> scanDirectory(String path) async {
    final dir = Directory(path);
    final List<MediaFileInfo> mediaFiles = [];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (_isMediaFile(extension)) {
          final stat = await entity.stat();
          mediaFiles.add(
            MediaFileInfo(
              path: entity.path,
              name: entity.path.split(Platform.pathSeparator).last,
              type: _getMediaType(extension),
              size: stat.size,
              modifiedTime: stat.modified,
              createdTime: stat.changed,
            ),
          );
        }
      }
    }

    return mediaFiles;
  }

  /// 同步单个文件
  Future<MediaFileInfo> syncFile(MediaFileInfo file) async {
    if (_storageEngine == null || _remoteBasePath == null) {
      return file.copyWith(
        syncStatus: SyncStatus.failed,
        syncError: '存储引擎未初始化',
      );
    }

    try {
      final remotePath = '${_remoteBasePath}/${file.name}';
      await _storageEngine!.uploadFile(File(file.path), remotePath);
      
      return file.copyWith(
        syncStatus: SyncStatus.synced,
        syncError: null,
        remotePath: remotePath,
      );
    } catch (e) {
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
