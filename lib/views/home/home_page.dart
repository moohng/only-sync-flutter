import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:only_sync_flutter/routes/route.dart';
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

    final activeId = prefs.getString('activeAccount');

    try {
      final accountList = accounts.map((e) => jsonDecode(e) as Map<String, dynamic>);
      Map<String, dynamic>? activeAccount;

      if (activeId != null && activeId.isNotEmpty) {
        activeAccount = accountList.firstWhere(
          (acc) => acc['id'] == activeId,
          orElse: () {
            // 如果找不到对应ID的账户，使用第一个账户并更新activeId
            final firstAccount = accountList.first;
            prefs.setString('activeAccount', firstAccount['id']);
            return firstAccount;
          },
        );
      } else if (accountList.isNotEmpty) {
        // 如果没有activeId但有账户，使用第一个账户
        activeAccount = accountList.first;
        prefs.setString('activeAccount', activeAccount['id']);
      }

      if (activeAccount != null) {
        activeService = WebDAVService(
          id: activeAccount['id'],
          name: activeAccount['name'],
          url: activeAccount['url'],
          username: activeAccount['username'] ?? '',
          password: activeAccount['password'] ?? '',
          remoteBasePath: activeAccount['path'] ?? '',
        );

        await _checkServiceAvailability();
        await Get.putAsync(() async => MediaGridController());
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

  // 修改切换存储服务的方法
  Future<void> switchStorageService(Map<String, dynamic> account) async {
    try {
      activeService = WebDAVService(
        id: account['id'],
        name: account['name'],
        url: account['url'],
        username: account['username'] ?? '',
        password: account['password'] ?? '',
        remoteBasePath: account['path'] ?? '',
      );

      await _checkServiceAvailability();
      // 更新同步状态存储
      final mediaController = Get.find<MediaGridController>();
      mediaController.updateStorageService(activeService, isAvailable: AppStore.to.isServiceAvailable.value);
      // 刷新媒体网格以显示新的同步状态
      mediaController.refresh();
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
          PopupMenuButton(
            icon: const Icon(Icons.add),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner),
                    SizedBox(width: 8),
                    Text('扫码添加'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manual',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 8),
                    Text('手动添加'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'scan') {
                final scanResult = await Get.toNamed(Routes.scanPage);
                if (scanResult != null) {
                  try {
                    final accountData = json.decode(scanResult as String);
                    Get.toNamed(Routes.addSyncPage, arguments: accountData);
                  } catch (e) {
                    Get.snackbar('错误', '无效的二维码数据');
                  }
                }
              } else if (value == 'manual') {
                Get.toNamed(Routes.addSyncPage);
              }
            },
          ),
        ],
      ),
      drawer: const SyncDrawer(),
      body: const MediaGrid(),
    );
  }
}
