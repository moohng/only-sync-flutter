import 'dart:convert';
import 'dart:io';
import 'package:webdav_client/webdav_client.dart' show newClient, Client;
import 'package:shared_preferences/shared_preferences.dart';

abstract class RemoteStorageService {
  Future<void> testConnection();
  Future<void> saveAccount();
  Future<void> uploadFile(String localPath, String remotePath);
  Future<bool> checkFileExists(String remotePath);
}

class WebDAVService extends RemoteStorageService {
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
      // 上传文件
      await client.writeFromFile(localPath, remotePath);
    } catch (e) {
      throw Exception('上传失败: $e');
    }
  }

  @override
  Future<bool> checkFileExists(String remotePath) async {
    try {
      await client.readProps(remotePath);
      return true;
    } catch (e) {
      print('检查文件存在失败: $e');
      return false;
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
