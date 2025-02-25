import 'dart:io';
import 'dart:async';
import 'package:get/get_connect/http/src/request/request.dart';
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
  late final SmbConnect _connect;
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
        _connect = await SmbConnect.connectAuth(
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
    await _connect.close();
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

        final smbFile = await _connect.createFile(normalizedPath);
        final writer = await _connect.openWrite(smbFile);
        final fileStream = file.openRead();
        writer.addStream(fileStream);
        await writer.flush();
        await writer.close();
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

        final smbFile = await _connect.file(normalizedPath);
        final reader = await _connect.openRead(smbFile);
        await file.writeAsString(await reader.bytesToString());
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
      final file = await _connect.file(normalizedPath);
      return file.isExists;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<StorageItem>> listDirectory(String remotePath) async {
    final items = <StorageItem>[];
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedPath = path.normalize(remotePath).replaceAll('\\', '/');
        final folder = await _connect.file(normalizedPath);
        final entries = await _connect.listFiles(folder);

        for (final entry in entries) {
          if (!entry.isExists) continue;

          items.add(StorageItem(
            path: path.join(remotePath, entry.name),
            info: StorageItemInfo(
              name: entry.name,
              type: entry.isDirectory() ? StorageItemType.directory : StorageItemType.file,
              size: entry.size,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(entry.lastModified),
            ),
          ));
        }
        break;
      } catch (e) {
        throw Exception('获取目录列表失败：$e');
      }
    }
    return items;
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
        await _connect.createFolder(normalizedPath);
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
        await _connect.delete(await _connect.file(normalizedPath));
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
        final info = await _connect.file(normalizedPath);
        if (!info.isExists) {
          throw Exception('文件不存在');
        }

        return StorageItemInfo(
          name: path.basename(normalizedPath),
          type: info.isDirectory() ? StorageItemType.directory : StorageItemType.file,
          size: info.size,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(info.lastModified),
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
