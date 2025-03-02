import 'dart:io';
import 'package:flutter/material.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaGridItem extends StatefulWidget {
  final MediaFileInfo file;
  final VoidCallback? onSync;
  final VoidCallback? onTap;

  const MediaGridItem({
    super.key,
    required this.file,
    this.onSync,
    this.onTap,
  });

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> with SingleTickerProviderStateMixin {
  late AnimationController _syncController;
  late Animation<double> _syncAnimation;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _syncAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _syncController,
      curve: Curves.easeInOut,
    ));

    // 当同步状态为syncing时，开始动画
    if (widget.file.syncStatus == SyncStatus.syncing) {
      _syncController.repeat();
    }
  }

  @override
  void didUpdateWidget(MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 监听同步状态变化
    if (widget.file.syncStatus != oldWidget.file.syncStatus) {
      if (widget.file.syncStatus == SyncStatus.syncing) {
        _syncController.repeat();
      } else {
        _syncController.stop();
      }
    }
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'media_${widget.file.path}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            // 媒体预览
            _buildPreview(),
            // 渐变遮罩
            _buildGradientOverlay(),
            // 同步状态指示器
            Positioned(
              top: 4,
              right: 4,
              child: _buildSyncButton(context),
            ),
            // 视频标识
            if (widget.file.type == MediaType.video)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            // 同步进度遮罩
            if (widget.file.syncStatus == SyncStatus.syncing)
              AnimatedBuilder(
                animation: _syncAnimation,
                builder: (context, child) {
                  return Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.blue.withOpacity(0.1),
                          ],
                          stops: [0.0, _syncAnimation.value],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.file.syncStatus == SyncStatus.notSynced ? widget.onSync : null,
      child: AnimatedBuilder(
        animation: _syncController,
        builder: (context, child) {
          return Transform.rotate(
            angle: widget.file.syncStatus == SyncStatus.syncing ? _syncController.value * 2 * 3.14159 : 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _getSyncStatusColor(widget.file.syncStatus),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getSyncStatusIcon(widget.file.syncStatus),
                color: Colors.white,
                size: 16,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.file is AssetEntityImageInfo) {
      final asset = (widget.file as AssetEntityImageInfo).asset;
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
      File(widget.file.thumbnailPath ?? widget.file.path),
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

  Widget _buildGradientOverlay() {
    return Positioned.fill(
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
    );
  }
}
