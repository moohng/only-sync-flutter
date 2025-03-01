import 'dart:io';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
