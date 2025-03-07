import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaGridItem extends StatefulWidget {
  final AssetEntityImageInfo file;
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'media_${widget.file.path}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            _buildPreview(),
            _buildGradientOverlay(),
            // 同步状态图标
            Positioned(
              top: 4,
              right: 4,
              child: Obx(() => AppStore.to.isServiceAvailable.value ? _buildSyncButton(context) : const SizedBox()),
            ),
            // 视频时长标识
            if (widget.file.type == MediaType.video)
              FutureBuilder<int>(
                future: Future.value(widget.file.asset.duration),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == 0) {
                    return const SizedBox();
                  }
                  return Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      // decoration: BoxDecoration(
                      //   color: Colors.black.withOpacity(0.7),
                      //   borderRadius: BorderRadius.circular(4),
                      // ),
                      child: Text(
                        _formatDuration(Duration(seconds: snapshot.data!)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            // 同步进度动画
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
                            Colors.blue.withAlpha(76),
                            Colors.blue.withAlpha(25),
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
    return AspectRatio(
      aspectRatio: 1, // 确保容器是正方形
      child: _buildMediaPreview(),
    );
  }

  Widget _buildMediaPreview() {
    final asset = widget.file.asset;

    // 优先使用缓存的缩略图
    if (widget.file.thumbnailPath != null) {
      return ExtendedImage.file(
        File(widget.file.thumbnailPath!),
        fit: BoxFit.cover,
        enableLoadState: true,
        // ...其他配置保持不变
      );
    }

    // 回退到原来的方案
    return ExtendedImage(
      image: AssetEntityImageProvider(
        asset,
        thumbnailSize: MediaManager.thumbnailSize,
        isOriginal: false,
      ),
      fit: BoxFit.cover,
      // ...其他配置保持不变
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
