import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';
import 'package:only_sync_flutter/views/home/widgets/media_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';

class HomeLogic extends GetxController {
  var pageIndex = 0.obs;
  var hasRemoteConfig = false.obs;
  WebDAVService? activeService;
  final isServiceAvailable = true.obs;

  @override
  void onInit() {
    super.onInit();
    checkRemoteConfig();
    _initStorageService();
  }

  void changePage(int index) {
    pageIndex.value = index;
  }

  Future<void> checkRemoteConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    hasRemoteConfig.value = accounts.isNotEmpty;
  }

  Future<void> _initStorageService() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    final activeUrl = prefs.getString('activeAccount');

    if (accounts.isEmpty || activeUrl == null) return;

    try {
      final activeAccount = accounts
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .firstWhere((acc) => acc['url'] == activeUrl, orElse: () => {});

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
        Get.find<MediaGridController>().updateStorageService(activeService, isAvailable: isServiceAvailable.value);
      }
    } catch (e) {
      isServiceAvailable.value = false;
      print('初始化存储服务失败: $e');
    }
  }

  Future<void> _checkServiceAvailability() async {
    try {
      if (activeService != null) {
        await activeService!.testConnection();
        isServiceAvailable.value = true;
      } else {
        isServiceAvailable.value = false;
      }
    } catch (e) {
      isServiceAvailable.value = false;
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
      Get.find<MediaGridController>().updateStorageService(activeService, isAvailable: isServiceAvailable.value);
    } catch (e) {
      isServiceAvailable.value = false;
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
        title: Row(
          children: [
            const Text('媒体同步'),
            const SizedBox(width: 8),
            Obx(() => Icon(
                  homeLogic.isServiceAvailable.value ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                  color: homeLogic.isServiceAvailable.value ? Colors.green : Colors.red,
                )),
          ],
        ),
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
      ),
      drawer: const SyncDrawer(),
      body: const MediaGrid(),
    );
  }
}
