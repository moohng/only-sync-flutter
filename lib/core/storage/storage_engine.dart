import 'dart:io';

/// 存储引擎接口，定义了与远程存储交互的基本操作
abstract class StorageEngine {
  /// 连接到远程存储
  Future<void> connect();

  /// 断开连接
  Future<void> disconnect();

  /// 上传文件
  Future<void> uploadFile(File file, String remotePath);

  /// 下载文件
  Future<File> downloadFile(String remotePath, String localPath);

  /// 检查文件是否存在
  Future<bool> exists(String remotePath);

  /// 列出目录内容
  Future<List<StorageItem>> listDirectory(String remotePath);

  /// 创建目录
  Future<void> createDirectory(String remotePath);

  /// 删除文件或目录
  Future<void> delete(String remotePath);

  /// 获取文件信息
  Future<StorageItemInfo> getItemInfo(String remotePath);
}

/// 存储项类型
enum StorageItemType {
  file,
  directory
}

/// 存储项信息
class StorageItemInfo {
  final String name;
  final StorageItemType type;
  final int size;
  final DateTime modifiedTime;

  StorageItemInfo({
    required this.name,
    required this.type,
    required this.size,
    required this.modifiedTime,
  });
}

/// 存储项
class StorageItem {
  final String path;
  final StorageItemInfo info;

  StorageItem({
    required this.path,
    required this.info,
  });
}