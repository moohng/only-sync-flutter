import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';
import 'package:only_sync_flutter/views/home/widgets/media_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeLogic extends GetxController {
  var pageIndex = 0.obs;
  var hasRemoteConfig = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkRemoteConfig();
  }

  void changePage(int index) {
    pageIndex.value = index;
  }

  Future<void> checkRemoteConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    hasRemoteConfig.value = accounts.isNotEmpty;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeLogic = Get.put(HomeLogic());

    return GetBuilder<SyncDrawerController>(
      init: SyncDrawerController(),
      builder: (drawerController) {
        return _buildMainScaffold(homeLogic, drawerController);
      },
    );
  }

  Widget _buildMainScaffold(HomeLogic homeLogic, SyncDrawerController drawerController) {
    return Scaffold(
      key: Get.nestedKey(1), // 添加唯一的key
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // 全部同步
              final controller = Get.find<MediaGridController>();
              controller.syncAll();
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 0,
                child: Text('添加账户'),
              ),
              PopupMenuItem(
                value: 1,
                child: Text('新建同步'),
              ),
            ],
            onSelected: (value) {
              log('选择了：$value');
              if (value == 0) {
                Get.toNamed(Routes.addAccountPage);
              } else if (value == 1) {
                Get.toNamed(Routes.addSyncPage);
              }
            },
          )
        ],
        title: const Text('媒体同步'),
      ),
      drawer: const SyncDrawer(),
      body: const MediaGrid(),
    );
  }
}
