import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';
import 'package:only_sync_flutter/views/home/widgets/media_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';

class HomeLogic extends GetxController {
  var pageIndex = 0.obs;
  WebDAVService? activeService;

  @override
  void onInit() {
    super.onInit();
    _initStorageService();
  }

  void changePage(int index) {
    pageIndex.value = index;
  }

  Future<void> _initStorageService() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    if (accounts.isEmpty) return;
    final activeUrl = prefs.getString('activeAccount');

    try {
      final accountList = accounts.map((e) => jsonDecode(e) as Map<String, dynamic>);
      Map<String, dynamic>? activeAccount;
      if (activeUrl != null && activeUrl.isNotEmpty) {
        activeAccount = accountList.firstWhere((acc) => acc['url'] == activeUrl);
      }
      if (activeAccount == null) {
        activeAccount = accountList.first;
        prefs.setString('activeAccount', activeAccount['url']);
      }

      if (activeAccount.isNotEmpty) {
        activeService = WebDAVService(
          name: activeAccount['name'],
          url: activeAccount['url'],
          username: activeAccount['username'] ?? '',
          password: activeAccount['password'] ?? '',
        );

        // 检查服务可用性
        await _checkServiceAvailability();

        // 确保 MediaGridController 已经初始化
        await Get.putAsync(() async => MediaGridController());
        // 更新存储服务
        Get.find<MediaGridController>()
            .updateStorageService(activeService, isAvailable: AppStore.to.isServiceAvailable.value);
      }
    } catch (e) {
      AppStore.to.updateServiceStatus(false);
      print('初始化存储服务失败: $e');
    }
  }

  Future<void> _checkServiceAvailability() async {
    try {
      if (activeService != null) {
        await activeService!.testConnection();
        AppStore.to.updateServiceStatus(true);
      } else {
        AppStore.to.updateServiceStatus(false);
      }
    } catch (e) {
      AppStore.to.updateServiceStatus(false);
      print('服务不可用: $e');
    }
  }

  // 添加切换存储服务的方法
  Future<void> switchStorageService(Map<String, dynamic> account) async {
    try {
      activeService = WebDAVService(
        name: account['name'],
        url: account['url'],
        username: account['username'] ?? '',
        password: account['password'] ?? '',
      );

      await _checkServiceAvailability();
      Get.find<MediaGridController>()
          .updateStorageService(activeService, isAvailable: AppStore.to.isServiceAvailable.value);
    } catch (e) {
      AppStore.to.updateServiceStatus(false);
      print('切换存储服务失败: $e');
      Get.snackbar('错误', '切换存储服务失败：$e');
    }
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
        forceMaterialTransparency: true,
        title: Obx(() => Row(
              children: [
                Text(homeLogic.activeService?.name ?? 'Only Sync'),
                const SizedBox(width: 8),
                Icon(
                  AppStore.to.isServiceAvailable.value ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                  color: AppStore.to.isServiceAvailable.value ? Colors.green : Colors.red,
                ),
              ],
            )),
        actions: [
          Obx(() => AppStore.to.isServiceAvailable.value
              ? IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    // 全部同步
                    final controller = Get.find<MediaGridController>();
                    controller.syncAll();
                  },
                )
              : const SizedBox()),
        ],
      ),
      drawer: const SyncDrawer(),
      body: const MediaGrid(),
    );
  }
}
