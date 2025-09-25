import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';
import 'package:only_sync_flutter/core/store/app_store.dart';
import 'package:only_sync_flutter/utils/encryption_util.dart';
import 'package:only_sync_flutter/views/home/widgets/media_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeLogic extends GetxController {
  WebDAVService? activeService;

  @override
  void onInit() {
    super.onInit();
    _initStorageService();
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
        // 解密
        final decryptedPassword = EncryptionUtil.decrypt(activeAccount['password'] ?? '');
        activeService = WebDAVService(
          id: activeAccount['id'],
          url: activeAccount['url'],
          username: activeAccount['username'] ?? '',
          password: decryptedPassword,
          remoteBasePath: activeAccount['path'] ?? '',
        );

        await _checkServiceAvailability();
        await Get.putAsync(() async => MediaGridController());
        Get.find<MediaGridController>()
            .updateStorageService(activeService, isAvailable: AppStore.to.currentServiceId.value.isNotEmpty);
      }
    } catch (e) {
      AppStore.to.updateService('');
      log('初始化存储服务失败: $e');
    }
  }

  Future<void> _checkServiceAvailability() async {
    try {
      if (activeService != null) {
        await activeService!.testConnection();
        AppStore.to.updateService(activeService!.id!);
      } else {
        AppStore.to.updateService('');
      }
    } catch (e) {
      AppStore.to.updateService('');
      log('服务不可用: $e');
    }
  }

  // 修改切换存储服务的方法
  Future<void> switchStorageService(Map<String, dynamic> account) async {
    try {
      final decryptedPassword = EncryptionUtil.decrypt(account['password'] ?? '');
      activeService = WebDAVService(
        id: account['id'],
        url: account['url'],
        username: account['username'] ?? '',
        password: decryptedPassword,
        remoteBasePath: account['path'] ?? '',
      );

      await _checkServiceAvailability();
      // 更新同步状态存储
      final mediaController = Get.find<MediaGridController>();
      mediaController.updateStorageService(activeService, isAvailable: AppStore.to.currentServiceId.value.isNotEmpty);
      // 刷新媒体网格以显示新的同步状态
      mediaController.refresh();
    } catch (e) {
      AppStore.to.updateService('');
      log('切换存储服务失败: $e');
      Get.snackbar('错误', '切换存储服务失败：$e');
    }
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(HomeLogic());
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      key: Get.nestedKey(1),
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: backgroundColor,
        title: Obx(() => Row(
              children: [
                const Text('Only Sync'),
                const SizedBox(width: 8),
                Icon(
                  AppStore.to.currentServiceId.value.isNotEmpty ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                  color: AppStore.to.currentServiceId.value.isNotEmpty ? Colors.green : Colors.red,
                ),
              ],
            )),
        actions: AppStore.to.currentServiceId.value.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    final controller = Get.find<MediaGridController>();
                    controller.addSelectAlbumFiles();
                  },
                ),
              ]
            : [],
      ),
      body: const MediaGrid(),
    );
  }
}
