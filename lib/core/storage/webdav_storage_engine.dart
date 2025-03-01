import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as path;
import 'package:only_sync_flutter/core/storage/storage_engine.dart';

/// WebDAV存储引擎，实现与WebDAV服务器的交互
class WebDAVStorageEngine implements StorageEngine {
  final String baseUrl;
  final String? username;
  final String? password;
  final Map<String, String>? headers;
  late final http.Client _client;
  late final Map<String, String> _defaultHeaders;

  WebDAVStorageEngine({
    required this.baseUrl,
    this.username,
    this.password,
    this.headers,
  });

  @override
  Future<void> connect() async {
    _client = http.Client();
    _defaultHeaders = {
      'Content-Type': 'application/xml',
      'Accept': '*/*',
      ...?headers,
    };

    if (username != null && password != null) {
      final credentials = base64.encode(utf8.encode('$username:$password'));
      _defaultHeaders['Authorization'] = 'Basic $credentials';
    }

    try {
      final response = await _client.send(
        http.Request('PROPFIND', Uri.parse(baseUrl))..headers.addAll(_defaultHeaders),
      );

      if (response.statusCode != 207) {
        throw Exception('WebDAV连接失败：${response.statusCode}');
      }
    } catch (e) {
      throw Exception('WebDAV连接失败：$e');
    }
  }

  @override
  Future<void> disconnect() async {
    _client.close();
  }

  @override
  Future<void> uploadFile(File file, String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final request = http.Request('PUT', uri)
      ..headers.addAll(_defaultHeaders)
      ..bodyBytes = await file.readAsBytes();

    final response = await _client.send(request);
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw Exception('文件上传失败：${response.statusCode}');
    }
  }

  @override
  Future<File> downloadFile(String remotePath, String localPath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final response = await _client.get(uri, headers: _defaultHeaders);

    if (response.statusCode != 200) {
      throw Exception('文件下载失败：${response.statusCode}');
    }

    final file = File(localPath);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  @override
  Future<bool> exists(String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final response = await _client.send(
      http.Request('PROPFIND', uri)..headers.addAll(_defaultHeaders),
    );
    return response.statusCode == 207;
  }

  @override
  Future<List<StorageItem>> listDirectory(String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(_defaultHeaders)
      ..body = '''<?xml version="1.0" encoding="utf-8" ?>
        <propfind xmlns="DAV:">
          <prop>
            <resourcetype/>
            <getcontentlength/>
            <getlastmodified/>
          </prop>
        </propfind>''';

    final response = await _client.send(request);
    if (response.statusCode != 207) {
      throw Exception('获取目录列表失败：${response.statusCode}');
    }

    final body = await response.stream.bytesToString();
    final document = xml.XmlDocument.parse(body);
    final items = <StorageItem>[];

    for (final response in document.findAllElements('response')) {
      final href = response.findElements('href').first.text;
      final prop = response.findElements('propstat').first.findElements('prop').first;
      final isDirectory = prop.findElements('resourcetype').first.findElements('collection').isNotEmpty;
      final size = int.tryParse(prop.findElements('getcontentlength').firstOrNull?.text ?? '0') ?? 0;
      final modified = DateTime.parse(prop.findElements('getlastmodified').first.text);

      items.add(StorageItem(
        path: href,
        info: StorageItemInfo(
          name: path.basename(href),
          type: isDirectory ? StorageItemType.directory : StorageItemType.file,
          size: size,
          modifiedTime: modified,
        ),
      ));
    }

    return items;
  }

  @override
  Future<void> createDirectory(String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final response = await _client.send(
      http.Request('MKCOL', uri)..headers.addAll(_defaultHeaders),
    );

    if (response.statusCode != 201) {
      throw Exception('创建目录失败：${response.statusCode}');
    }
  }

  @override
  Future<void> delete(String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final response = await _client.send(
      http.Request('DELETE', uri)..headers.addAll(_defaultHeaders),
    );

    if (response.statusCode != 204) {
      throw Exception('删除失败：${response.statusCode}');
    }
  }

  @override
  Future<StorageItemInfo> getItemInfo(String remotePath) async {
    final uri = Uri.parse(path.join(baseUrl, remotePath));
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(_defaultHeaders)
      ..body = '''<?xml version="1.0" encoding="utf-8" ?>
        <propfind xmlns="DAV:">
          <prop>
            <resourcetype/>
            <getcontentlength/>
            <getlastmodified/>
          </prop>
        </propfind>''';

    final response = await _client.send(request);
    if (response.statusCode != 207) {
      throw Exception('获取文件信息失败：${response.statusCode}');
    }

    final body = await response.stream.bytesToString();
    final document = xml.XmlDocument.parse(body);
    final prop = document.findAllElements('prop').first;

    final isDirectory = prop.findElements('resourcetype').first.findElements('collection').isNotEmpty;
    final size = int.tryParse(prop.findElements('getcontentlength').firstOrNull?.text ?? '0') ?? 0;
    final modified = DateTime.parse(prop.findElements('getlastmodified').first.text);

    return StorageItemInfo(
      name: path.basename(remotePath),
      type: isDirectory ? StorageItemType.directory : StorageItemType.file,
      size: size,
      modifiedTime: modified,
    );
  }

  @override
  String? id;

  @override
  // TODO: implement name
  String get name => throw UnimplementedError();

  @override
  Future<void> saveAccount() {
    // TODO: implement saveAccount
    throw UnimplementedError();
  }

  @override
  Future<void> testConnection() {
    // TODO: implement testConnection
    throw UnimplementedError();
  }

  @override
  // TODO: implement type
  String get type => throw UnimplementedError();

  @override
  // TODO: implement url
  String get url => throw UnimplementedError();
}
