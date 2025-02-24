import 'dart:io';
import 'dart:async';
import 'package:smb_connect/smb_connect.dart';
import 'package:path/path.dart' as path;
import 'package:only_sync_flutter/core/storage/storage_engine.dart';

/// SMB存储引擎，实现与SMB/CIFS文件共享服务器的交互
class SMBStorageEngine implements StorageEngine {
  final String host;
  final int port;
  final String shareName;
  final String? username;
  final String? password;
  final String? domain;
  late final SmbConnect _client;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  SMBStorageEngine({
    required this.host,
    this.port = 445,
    required this.shareName,
    this.username,
    this.password,
    this.domain,
  });

  @override
  Future<void> connect() async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        _client = await SmbConnect.connectAuth(
          host: host,
          domain: domain ?? '',
          username: username ?? 'guest',
          password: password ?? '',
        );
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('SMB连接失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _client.close();
  }

  @override
  Future<void> uploadFile(File file, String remotePath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final parentDir = path.dirname(normalizedPath);
        if (parentDir != '.') {
          await createDirectory(parentDir);
        }

        final fileStream = file.openRead();
        await _client.writeFile(normalizedPath, fileStream);
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('文件上传失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  Future<File> downloadFile(String remotePath, String localPath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final file = File(localPath);
        final parentDir = path.dirname(localPath);
        await Directory(parentDir).create(recursive: true);

        final stream = await _client.readFile(normalizedPath);
        await file.writeAsBytes(await stream.toBytes());
        return file;
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('文件下载失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
    throw Exception('文件下载失败：未知错误');
  }

  @override
  Future<bool> exists(String remotePath) async {
    try {
      final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
      final info = await _client.getFileInformation(normalizedPath);
      return info != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<StorageItem>> listDirectory(String remotePath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final items = <StorageItem>[];
        final entries = await _client.listDirectory(normalizedPath);

      for (final entry in entries) {
        if (entry.filename == '.' || entry.filename == '..') continue;

        items.add(StorageItem(
          path: path.join(remotePath, entry.filename),
          info: StorageItemInfo(
            name: entry.filename,
            type: entry.isDirectory ? StorageItemType.directory : StorageItemType.file,
            size: entry.endOfFile,
            modifiedTime: entry.lastWriteTime,
          ),
        ));
      }

      return items;
    } catch (e) {
      throw Exception('获取目录列表失败：$e');
    }
  }

  @override
  Future<void> createDirectory(String remotePath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final parentDir = path.dirname(normalizedPath);
        if (parentDir != '.' && !await exists(parentDir)) {
          await createDirectory(parentDir);
        }
        await _client.createDirectory(normalizedPath);
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('创建目录失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  Future<void> delete(String remotePath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final info = await _client.getFileInformation(normalizedPath);
        if (info == null) return;

        if (info.isDirectory) {
          final items = await listDirectory(normalizedPath);
          for (final item in items) {
            await delete(item.path);
          }
          await _client.deleteDirectory(normalizedPath);
        } else {
          await _client.deleteFile(normalizedPath);
        }
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('删除失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  Future<StorageItemInfo> getItemInfo(String remotePath) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final info = await _client.getFileInformation(normalizedPath);
        if (info == null) {
          throw Exception('文件不存在');
        }

        return StorageItemInfo(
          name: path.basename(normalizedPath),
          type: info.isDirectory ? StorageItemType.directory : StorageItemType.file,
          size: info.endOfFile,
          modifiedTime: info.lastWriteTime,
        );
      } catch (e) {
        if (i == maxRetries - 1) {
          throw Exception('获取文件信息失败（已重试$maxRetries次）：$e');
        }
        await Future.delayed(retryDelay);
      }
    }
    throw Exception('获取文件信息失败：未知错误');
  }
}
