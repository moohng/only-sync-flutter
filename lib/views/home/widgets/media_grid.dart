import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';

class MediaGridController extends GetxController {
  final mediaFiles = <MediaFileInfo>[].obs;
  final isLoading = true.obs;
  final MediaManager _mediaManager = MediaManager();

  Future<void> loadMediaFiles(String directory) async {
    isLoading.value = true;
    try {
      mediaFiles.value = await _mediaManager.scanDirectory(directory);
    } catch (e) {
      Get.snackbar('错误', '加载媒体文件失败：$e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncFile(MediaFileInfo file) async {
    final index = mediaFiles.indexWhere((f) => f.path == file.path);
    if (index == -1) return;

    mediaFiles[index] = mediaFiles[index].copyWith(syncStatus: SyncStatus.syncing);
    final result = await _mediaManager.syncFile(file);
    mediaFiles[index] = result;

    if (result.syncStatus == SyncStatus.failed) {
      Get.snackbar('同步失败', result.syncError ?? '未知错误');
    }
  }

  Future<void> syncAll() async {
    final unsynced = mediaFiles.where((f) => f.syncStatus == SyncStatus.notSynced).toList();
    if (unsynced.isEmpty) return;

    for (final file in unsynced) {
      await syncFile(file);
    }
  }
}

class MediaGrid extends StatelessWidget {
  const MediaGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MediaGridController());

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.mediaFiles.isEmpty) {
        return const Center(child: Text('没有找到媒体文件'));
      }

      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: controller.mediaFiles.length,
        itemBuilder: (context, index) {
          final file = controller.mediaFiles[index];
          return MediaGridItem(
            file: file,
            onSync: () => controller.syncFile(file),
          );
        },
      );
    });
  }
}

class MediaGridItem extends StatelessWidget {
  final MediaFileInfo file;
  final VoidCallback? onSync;

  const MediaGridItem({super.key, required this.file, this.onSync});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 媒体缩略图
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // 同步状态指示器
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: file.syncStatus == SyncStatus.notSynced ? onSync : null,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _getSyncStatusColor(file.syncStatus),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getSyncStatusIcon(file.syncStatus),
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        // 视频标识
        if (file.type == MediaType.video)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
      ],
    );
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.notSynced:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
    }
  }

  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.notSynced:
        return Icons.cloud_upload_outlined;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.synced:
        return Icons.cloud_done;
      case SyncStatus.failed:
        return Icons.error_outline;
    }
  }
}
