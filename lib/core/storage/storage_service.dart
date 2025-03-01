import 'dart:convert';
// import 'package:only_sync_flutter/core/storage/smb_storage_engine.dart';
import 'package:only_sync_flutter/core/storage/webdav_storage_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart';

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
  final String url;
  final String username;
  final String password;

  WebDAVService({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
  });

  @override
  Future<void> testConnection() async {
    try {
      final client = newClient(url, user: username, password: password);
      await client.ping();
    } catch (e) {
      throw Exception('WebDAV连接测试失败：$e');
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
}
