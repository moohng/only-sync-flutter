import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';
import 'package:only_sync_flutter/views/home/views/media_preview_page.dart';
import 'package:intl/intl.dart';
import 'package:only_sync_flutter/views/home/widgets/media_grid_item.dart';
import 'package:photo_manager/photo_manager.dart';

// 记录当前相册的加载状态
class AlbumState {
  final List<AssetEntityImageInfo> files;
  final int currentPage;
  final bool hasMore;

  AlbumState({
    required this.files,
    this.currentPage = 0,
    this.hasMore = true,
  });
}

class MediaGridController extends GetxController with GetTickerProviderStateMixin {
  static const int pageSize = 30;

  final mediaFiles = <AssetEntityImageInfo>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  final currentPath = ''.obs;
  final MediaManager _mediaManager = MediaManager();

  final albums = <AssetPathEntity>[].obs;
  final selectedAlbum = Rxn<AssetPathEntity>();
  final page = 0.obs;

  // 缓存相册资源
  final assetCache = <String, AssetEntity>{}.obs;
  late AnimationController fadeController;

  // 添加加载状态控制
  final isLoadingMore = false.obs;
  final isFirstLoad = true.obs;
  final isInitializing = true.obs;
  final isServiceAvailable = true.obs;

  // 添加相册状态缓存
  final albumStates = <String, AlbumState>{}.obs;

  // 用于取消后台任务的标记
  String? currentAlbumId;

  @override
  void onInit() {
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    super.onInit();
    isInitializing.value = true;
    _initMediaManager();
    _mediaManager.onSyncStatusChanged = _updateFileStatus;
  }

  void _updateFileStatus(AssetEntityImageInfo updatedFile) {
    final index = mediaFiles.indexWhere((f) => f.path == updatedFile.path);
    if (index != -1) {
      mediaFiles[index] = updatedFile;
      // 使用 refresh() 而不是 update() 避免整个列表重建
      mediaFiles.refresh();
    }
  }

  @override
  void onClose() {
    fadeController.dispose();
    super.onClose();
  }

  void updateStorageService(RemoteStorageService? service, {bool isAvailable = true}) {
    _mediaManager.updateStorageService(service);
    isServiceAvailable.value = isAvailable;
  }

  Future<void> _initMediaManager() async {
    try {
      await _mediaManager.init();
      final hasPermission = await _mediaManager.requestPermission();
      if (!hasPermission) {
        Get.snackbar('提示', '需要相册访问权限才能继续');
        return;
      }

      final albumList = await _mediaManager.getAlbums();
      albums.value = albumList;

      if (albumList.isNotEmpty) {
        selectedAlbum.value = albumList[0]; // 默认选择第一个相册
        await loadNextBatch();
      }
    } catch (e) {
      log('初始化失败: $e');
      Get.snackbar('错误', '初始化失败：$e');
    }
  }

  Future<void> loadNextBatch() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value || selectedAlbum.value == null) return;
    isLoadingMore.value = true;

    try {
      final files = await _mediaManager.getMediaFiles(
        album: selectedAlbum.value!,
        page: page.value,
        pageSize: pageSize,
      );
      log('============== ${files.length}');

      if (files.isEmpty) {
        hasMore.value = false;
      } else {
        // 过滤已加载的资源
        if (files.length < pageSize) {
          hasMore.value = false;
        }
        if (files.isNotEmpty) {
          if (page.value == 0) {
            mediaFiles.clear();
          }
          mediaFiles.addAll(files);
          page.value++;
        }
      }
    } catch (e) {
      log('加载失败: $e');
    } finally {
      isLoadingMore.value = false;
      isFirstLoad.value = false;
      isInitializing.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    if (isLoading.value) return;

    // 清除当前相册的缓存状态
    if (selectedAlbum.value != null) {
      albumStates.remove(selectedAlbum.value!.id);
    }

    page.value = 0;
    hasMore.value = true;
    await loadNextBatch();
  }

  /// 添加单个文件到同步队列
  Future<void> addFile(AssetEntityImageInfo file) async {
    if (file.syncStatus != SyncStatus.synced) {
      // 添加到后台同步队列
      _mediaManager.addToSyncQueue(file);
    }
  }

  /// 将当前相册所有未同步的文件添加到同步队列
  Future<void> addSelectAlbumFiles() async {
    final albumFiles = await _mediaManager.getMediaFiles(album: selectedAlbum.value!);
    for (final file in albumFiles) {
      // 添加到后台同步队列
      if (file.syncStatus != SyncStatus.synced) {
        _mediaManager.addToSyncQueue(file);
      }
    }
  }

  /// 获取按月份分组的媒体文件
  Map<String, List<AssetEntityImageInfo>> get groupedMediaFiles {
    final grouped = <String, List<AssetEntityImageInfo>>{};
    for (final file in mediaFiles) {
      final month = DateFormat('yyyy年MM月').format(file.modifiedTime);
      if (!grouped.containsKey(month)) {
        grouped[month] = [];
      }
      grouped[month]!.add(file);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  void showPreview(List<AssetEntityImageInfo> files, int initialIndex) {
    Get.to(() => MediaPreviewPage(
          files: files,
          initialIndex: initialIndex,
        ));
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    if (selectedAlbum.value?.id != album.id) {
      // 保存当前相册状态
      if (selectedAlbum.value != null) {
        albumStates[selectedAlbum.value!.id] = AlbumState(
          files: mediaFiles.toList(),
          currentPage: page.value,
          hasMore: hasMore.value,
        );
      }

      selectedAlbum.value = album;
      currentAlbumId = album.id;

      // 恢复相册状态或重新加载
      if (albumStates.containsKey(album.id)) {
        final state = albumStates[album.id]!;
        mediaFiles.value = state.files;
        page.value = state.currentPage;
        hasMore.value = state.hasMore;
        isInitializing.value = false;
      } else {
        mediaFiles.clear();
        page.value = 0;
        hasMore.value = true;
        isInitializing.value = true;
        await loadNextBatch();
      }
    }
  }

  // 预加载图片
  Future<void> preloadImages(List<AssetEntity> assets) async {
    for (var asset in assets) {
      final file = await asset.file;
      if (file != null) {
        precacheImage(FileImage(file), Get.context!);
      }
    }
  }
}

class MediaGrid extends StatelessWidget {
  const MediaGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MediaGridController());
    final scrollController = ScrollController();

    // 添加滚动监听
    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 500) {
        controller.loadNextBatch();
      }
    });

    return GetBuilder<MediaGridController>(
      init: MediaGridController(),
      builder: (controller) {
        return Obx(() => Column(
              children: [
                // 相册选择器
                if (controller.albums.isNotEmpty) _buildAlbumSelector(controller),
                // 媒体网格
                Expanded(
                  child: _buildMediaGrid(controller, scrollController),
                ),
              ],
            ));
      },
    );
  }

  Widget _buildAlbumSelector(MediaGridController controller) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: controller.albums.length,
        itemBuilder: (context, index) {
          final album = controller.albums[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Obx(
              () => ActionChip(
                labelStyle: const TextStyle(fontSize: 12),
                // elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: BorderSide(
                    color: controller.selectedAlbum.value?.id == album.id
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withOpacity(0.1),
                  ),
                ),
                backgroundColor: controller.selectedAlbum.value?.id == album.id
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withOpacity(0.1),
                label: FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) => Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              album.isAll ? '全部' : album.name,
                              style: TextStyle(
                                color: controller.selectedAlbum.value?.id == album.id ? Colors.white : Colors.black,
                              ),
                            ),
                            if (snapshot.hasData) ...[
                              const SizedBox(width: 4),
                              Text(
                                snapshot.data.toString(),
                                style: TextStyle(
                                  color:
                                      controller.selectedAlbum.value?.id == album.id ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        )),
                onPressed: () => controller.selectAlbum(album),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaGrid(MediaGridController controller, ScrollController scrollController) {
    return Obx(() {
      if (controller.isInitializing.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final grouped = controller.groupedMediaFiles;

      // 添加一个额外的容器来确保有足够的滚动空间
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (grouped.isEmpty && !controller.isFirstLoad.value) {
              return SingleChildScrollView(
                // 确保内容至少有一个屏幕高，这样才能下拉刷新
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(child: Text('暂无媒体文件'))),
              );
            }
            return CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...grouped.entries.map((entry) => SliverMediaGroup(
                      month: entry.key,
                      files: entry.value,
                      onTapItem: (index) => controller.showPreview(
                        entry.value,
                        index,
                      ),
                    )),
                if (controller.hasMore.value && !controller.isFirstLoad.value)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                // 添加底部间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

class SliverMediaGroup extends StatelessWidget {
  final String month;
  final List<AssetEntityImageInfo> files;
  final Function(int) onTapItem;

  const SliverMediaGroup({
    super.key,
    required this.month,
    required this.files,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              month,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) => MediaGridItem(
              file: files[index],
              onSync: () => Get.find<MediaGridController>().addFile(files[index]),
              onTap: () => onTapItem(index),
            ),
          ),
        ],
      ),
    );
  }
}
