import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class MediaGridController extends GetxController with GetTickerProviderStateMixin {
  static const int pageSize = 30;

  final mediaFiles = <MediaFileInfo>[].obs;
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

  @override
  void onInit() {
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    super.onInit();
    isInitializing.value = true;
    _initMediaManager();
  }

  @override
  void onClose() {
    fadeController.dispose();
    super.onClose();
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
      print('初始化失败: $e');
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
      print('============== ${files.length}');

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
      print('加载失败: $e');
    } finally {
      isLoadingMore.value = false;
      isFirstLoad.value = false;
      isInitializing.value = false;
    }
  }

  Future<void> refresh() async {
    if (isLoading.value) return;
    page.value = 0;
    hasMore.value = true;
    // isInitializing.value = true;
    await loadNextBatch();
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

  /// 获取按月份分组的媒体文件
  Map<String, List<MediaFileInfo>> get groupedMediaFiles {
    final grouped = <String, List<MediaFileInfo>>{};
    for (final file in mediaFiles) {
      final month = DateFormat('yyyy年MM月').format(file.modifiedTime);
      if (!grouped.containsKey(month)) {
        grouped[month] = [];
      }
      grouped[month]!.add(file);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  void showPreview(List<MediaFileInfo> files, int initialIndex) {
    Get.to(() => MediaPreviewPage(
          files: files,
          initialIndex: initialIndex,
        ));
  }

  void selectAlbum(AssetPathEntity album) {
    if (selectedAlbum.value?.id != album.id) {
      selectedAlbum.value = album;
      mediaFiles.clear();
      isInitializing.value = true;
      refresh();
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
            blurRadius: 4,
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
            child: Obx(() => ActionChip(
                  avatar: FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) {
                      return Text(
                        '${snapshot.data ?? 0}',
                        style: TextStyle(
                          color: controller.selectedAlbum.value?.id == album.id ? Colors.white : Colors.grey,
                        ),
                      );
                    },
                  ),
                  backgroundColor: controller.selectedAlbum.value?.id == album.id
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withOpacity(0.1),
                  label: Text(
                    album.name,
                    style: TextStyle(
                      color: controller.selectedAlbum.value?.id == album.id ? Colors.white : Colors.black,
                    ),
                  ),
                  onPressed: () => controller.selectAlbum(album),
                )),
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
      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: controller.refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: scrollController,
                  // 确保内容至少有一个屏幕高，这样才能下拉刷新
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: grouped.isEmpty && !controller.isFirstLoad.value
                        ? const Center(child: Text('暂无媒体文件'))
                        : CustomScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
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
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class SliverMediaGroup extends StatelessWidget {
  final String month;
  final List<MediaFileInfo> files;
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
              onSync: () => Get.find<MediaGridController>().syncFile(files[index]),
              onTap: () => onTapItem(index),
            ),
          ),
        ],
      ),
    );
  }
}

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

// 修改MediaPreviewPage的图片加载逻辑
class MediaPreviewPage extends StatefulWidget {
  final List<MediaFileInfo> files;
  final int initialIndex;

  const MediaPreviewPage({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late PageController _pageController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int _currentIndex = 0;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    if (widget.files[widget.initialIndex].type == MediaType.video) {
      _initializeVideoPlayer(widget.files[widget.initialIndex]);
    }
  }

  @override
  void dispose() {
    _cleanupVideo();
    _pageController.dispose();
    super.dispose();
  }

  void _cleanupVideo() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _initializeVideoPlayer(MediaFileInfo file) async {
    if (!mounted) return;

    setState(() => _isVideoLoading = true);

    try {
      // 清理之前的视频控制器
      _cleanupVideo();

      if (file.type != MediaType.video) return;

      final videoFile = File(file.path);
      if (!await videoFile.exists()) {
        throw Exception('视频文件不存在');
      }

      _videoController = VideoPlayerController.file(videoFile);

      await _videoController!.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 42),
                const SizedBox(height: 8),
                Text(
                  '视频加载失败: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('视频初始化失败: $e');
      _cleanupVideo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          final file = widget.files[index];
          if (file.type == MediaType.video) {
            _initializeVideoPlayer(file);
          } else {
            _cleanupVideo();
          }
        },
        itemBuilder: (context, index) {
          final file = widget.files[index];
          if (file.type == MediaType.video && index == _currentIndex) {
            return _buildVideoPreview(file);
          }
          return _buildImagePreview(file);
        },
      ),
    );
  }

  Widget _buildVideoPreview(MediaFileInfo file) {
    if (_isVideoLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_chewieController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _initializeVideoPlayer(file),
              child: const Text(
                '重试',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildImagePreview(MediaFileInfo file) {
    return Hero(
      tag: 'media_${file.path}',
      child: ExtendedImage(
        image: file is AssetEntityImageInfo
            ? AssetEntityImageProvider(file.asset, isOriginal: true)
            : FileImage(File(file.path)) as ImageProvider,
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (state) => GestureConfig(
          minScale: 0.9,
          maxScale: 3.0,
          animationMaxScale: 3.5,
          animationMinScale: 0.8,
        ),
        loadStateChanged: (state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            case LoadState.failed:
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.white70, size: 64),
              );
            case LoadState.completed:
              return null;
          }
        },
      ),
    );
  }
}
