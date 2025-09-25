import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:only_sync_flutter/utils/common_util.dart';
import 'package:webdav_client/webdav_client.dart' show newClient, Client;
import 'package:shared_preferences/shared_preferences.dart';

abstract class RemoteStorageService {
  late String? id;
  Future<void> testConnection();
  Future<void> saveAccount();
  Future<void> uploadFile(String localPath, String remotePath);
  Future<bool> checkFileExists(String remotePath);
}

class WebDAVService extends RemoteStorageService {
  final String url;
  final String username;
  final String password;
  String? remoteBasePath;
  late final Client client;

  WebDAVService({
    required this.url,
    required this.username,
    required this.password,
    String? id,
    String? remoteBasePath,
  }) {
    super.id = id;
    client = newClient(
      url,
      user: username,
      password: password,
      debug: true,
    );
    initRemoteBasePath(remoteBasePath);
  }

  void initRemoteBasePath(String? remoteBasePath) async {
    if (remoteBasePath == null || remoteBasePath.isEmpty) {
      final deviceName = await CommonUtil.getDeviceName();
      this.remoteBasePath = '/$deviceName';
    } else {
      this.remoteBasePath = remoteBasePath;
    }
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
      await client.writeFromFile(localPath, '$remoteBasePath/$remotePath');
    } catch (e) {
      throw Exception('上传失败: $e');
    }
  }

  @override
  Future<bool> checkFileExists(String remotePath) async {
    try {
      await client.readProps('$remoteBasePath/$remotePath');
      return true;
    } catch (e) {
      log('检查文件存在失败: $e');
      return false;
    }
  }
}
