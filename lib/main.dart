import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/thumbnail_cache.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:only_sync_flutter/routes/route.dart';

void main() {
  // 初始化全局状态
  Get.put(AppStore(), permanent: true);

  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 500 << 20;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Only Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey.shade200),
        useMaterial3: true,
      ),
      initialRoute: Routes.homePage,
      getPages: Routes.getPages(),
      onDispose: () async {
        // 清理过期的缩略图缓存
        await ThumbnailCache().clearCache();
      },
    );
  }
}
