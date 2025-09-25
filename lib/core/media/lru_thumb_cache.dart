import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

class LruThumbCache {
  final int capacity;
  final _cache = <String, Uint8List?>{};

  LruThumbCache({this.capacity = 200});

  Future<Uint8List?> getThumb(AssetEntity asset, {int size = 200}) async {
    final key = asset.id;

    // 命中缓存
    if (_cache.containsKey(key)) {
      final data = _cache.remove(key);
      if (data != null) {
        // 移到最后（表示最近使用）
        _cache[key] = data;
      }
      return data;
    }

    // 生成缩略图
    final thumb = await asset.thumbnailDataWithSize(ThumbnailSize(size, size));

    // 加入缓存
    _cache[key] = thumb;

    // 超出容量 → 移除最早的
    if (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }

    return thumb;
  }
}
