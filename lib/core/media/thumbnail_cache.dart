import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ThumbnailCache {
  static final ThumbnailCache _instance = ThumbnailCache._internal();
  factory ThumbnailCache() => _instance;
  ThumbnailCache._internal();

  late Directory _cacheDir;
  final Map<String, String> _memoryCache = {};

  Future<void> init() async {
    final appDir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${appDir.path}/thumbnails');
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  String _generateCacheKey(String assetId, int width, int height) {
    final key = '$assetId-${width}x$height';
    return md5.convert(utf8.encode(key)).toString();
  }

  Future<String?> getThumbnailPath(String assetId, int width, int height) async {
    final cacheKey = _generateCacheKey(assetId, width, height);

    // 检查内存缓存
    if (_memoryCache.containsKey(cacheKey)) {
      final path = _memoryCache[cacheKey];
      if (path != null && File(path).existsSync()) {
        return path;
      }
    }

    // 检查文件缓存
    final cachePath = '${_cacheDir.path}/$cacheKey';
    if (File(cachePath).existsSync()) {
      _memoryCache[cacheKey] = cachePath;
      return cachePath;
    }

    return null;
  }

  Future<String> saveThumbnail(String assetId, List<int> bytes, int width, int height) async {
    final cacheKey = _generateCacheKey(assetId, width, height);
    final cachePath = '${_cacheDir.path}/$cacheKey';

    await File(cachePath).writeAsBytes(bytes);
    _memoryCache[cacheKey] = cachePath;
    return cachePath;
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    if (_cacheDir.existsSync()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create(recursive: true);
    }
  }
}
