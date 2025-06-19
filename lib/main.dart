import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/media/thumbnail_cache.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:only_sync_flutter/routes/route.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';
import 'package:only_sync_flutter/views/settings/settings_page.dart';
import 'package:only_sync_flutter/views/sync/sync_page.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey.shade200, secondary: const Color(0xff10b981)),
        useMaterial3: true,
        primaryColor: const Color(0xff3b82f6),
        cardColor: Colors.white,
        dividerColor: const Color.fromARGB(255, 229, 231, 235),
        scaffoldBackgroundColor: const Color.fromARGB(255, 242, 244, 246),
      ),
      home: const MainPage(),
      getPages: Routes.getPages(),
      onDispose: () async {
        // 清理过期的缩略图缓存
        await ThumbnailCache().clearCache();
      },
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MainController());

    return Scaffold(
      body: Obx(() => IndexedStack(
            index: controller.tabIndex.value,
            children: const [
              HomePage(),
              SyncPage(),
              SettingsPage(),
            ],
          )),
      bottomNavigationBar: Obx(() => NavigationBar(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: controller.changeTabIndex,
            indicatorColor: Colors.transparent,
            // overlayColor: WidgetStatePropertyAll(Colors.amberAccent),
            // elevation: 18,
            // shadowColor: Colors.black26,
            // indicatorShape: const StadiumBorder(),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.photo_outlined),
                selectedIcon: Icon(Icons.photo),
                label: '相册',
              ),
              NavigationDestination(
                icon: Icon(Icons.cloud_outlined),
                selectedIcon: Icon(Icons.cloud),
                label: '同步',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          )),
    );
  }
}

class MainController extends GetxController {
  var tabIndex = 0.obs;
  void changeTabIndex(int index) => tabIndex.value = index;
}
