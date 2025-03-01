import 'dart:convert';
import 'dart:io';
import 'package:only_sync_flutter/core/storage/webdav_storage_engine.dart';
import 'package:webdav_client/webdav_client.dart' show newClient, Client;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageService {
  Future<void> testConnection();
  Future<void> saveAccount();
  Future<void> uploadFile(String localPath, String remotePath);
}

class SMBService extends StorageService {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String path;

  SMBService({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.path,
  });

  @override
  Future<void> testConnection() async {
    final engine = WebDAVStorageEngine(
      baseUrl: '$host:$port$path',
      username: username,
      password: password,
    );

    try {
      await engine.connect();
      await engine.disconnect();
    } catch (e) {
      throw Exception('SMB连接测试失败：$e');
    }
  }

  @override
  Future<void> saveAccount() async {
    final account = {
      'type': 'SMB',
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'path': path,
    };

    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    accounts.add(jsonEncode(account));
    await prefs.setStringList('accounts', accounts);
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    // Implement SMB file upload logic here
  }
}

class WebDAVService extends StorageService {
  final String name;
  final String url;
  final String username;
  final String password;
  late final Client client;

  WebDAVService({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
  }) {
    client = newClient(
      url,
      user: username,
      password: password,
      debug: true,
    );
  }

  @override
  Future<void> testConnection() async {
    try {
      await client.ping();
    } catch (e) {
      throw Exception('连接失败: $e');
    }
  }

  @override
  Future<void> saveAccount() async {
    final account = {
      'type': 'WebDAV',
      'name': name,
      'url': url,
      'username': username,
      'password': password,
    };

    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    accounts.add(jsonEncode(account));
    await prefs.setStringList('accounts', accounts);
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    // 判断文件是否存在
    if (!File(localPath).existsSync()) {
      throw Exception('文件不存在: $localPath');
    }

    try {
      // 确保远程目录存在
      final dir = path.dirname(remotePath);
      await _createDirectory(dir);

      // 上传文件
      await client.writeFromFile(localPath, remotePath);
    } catch (e) {
      throw Exception('上传失败: $e');
    }
  }

  Future<void> _createDirectory(String remotePath) async {
    try {
      try {
        await client.readDir(remotePath);
      } catch (e) {
        await client.mkdirAll(remotePath);
      }
    } catch (e) {
      throw Exception('创建目录失败: $e');
    }
  }
}
