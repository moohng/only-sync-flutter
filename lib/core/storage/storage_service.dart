import 'dart:convert';
import 'dart:io';
// import 'package:only_sync_flutter/core/storage/smb_storage_engine.dart';
import 'package:only_sync_flutter/core/storage/webdav_storage_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageService {
  Future<void> testConnection();
  Future<void> saveAccount();
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
}

class WebDAVService extends StorageService {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String path;

  WebDAVService({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.path,
  });

  @override
  Future<void> testConnection() async {
    final protocol = port == 443 ? 'https' : 'http';
    final url = '$protocol://$host:$port$path';

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.add('Authorization', 'Basic ${base64Encode(utf8.encode('$username:$password'))}');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('服务器返回错误：${response.statusCode}');
      }
    } catch (e) {
      throw Exception('WebDAV连接测试失败：$e');
    }
  }

  @override
  Future<void> saveAccount() async {
    final account = {
      'type': 'WebDAV',
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
}
