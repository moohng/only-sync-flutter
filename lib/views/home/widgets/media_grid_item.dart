import 'dart:io';
import 'package:flutter/material.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:extended_image/extended_image.dart';

class MediaGridItem extends StatelessWidget {
  final MediaFileInfo file;
  final VoidCallback? onSync;
  final VoidCallback? onTap;

  const MediaGridItem({super.key, required this.file, this.onSync, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'media_${file.path}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              width: 0.5,
            ),
            // borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            // borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(),
                // 渐变遮罩
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (file is AssetEntityImageInfo) {
      final asset = (file as AssetEntityImageInfo).asset;
      return ExtendedImage(
        image: AssetEntityImageProvider(
          asset,
          thumbnailSize: const ThumbnailSize(200, 200),
          isOriginal: false,
        ),
        fit: BoxFit.cover,
        loadStateChanged: (state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            case LoadState.failed:
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              );
            case LoadState.completed:
              return ExtendedRawImage(
                image: state.extendedImageInfo?.image,
                fit: BoxFit.cover,
              );
          }
        },
      );
    }
    return Image.file(
      File(file.thumbnailPath ?? file.path),
      fit: BoxFit.cover,
      cacheWidth: 200,
      cacheHeight: 200,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        );
      },
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
