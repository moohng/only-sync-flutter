import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';
import '../../../routes/route.dart';

class AccountInfo {
  const AccountInfo(
      {required this.name, this.icon = Icons.account_circle_outlined, this.selectedIcon = Icons.account_circle});

  final String name;
  final IconData icon;
  final IconData selectedIcon;
}

class SyncInfo {
  const SyncInfo({required this.name, this.icon = Icons.cloud_sync_outlined, this.selectedIcon = Icons.cloud_sync});

  final String name;
  final IconData icon;
  final IconData selectedIcon;
}

class SyncDrawerController extends GetxController {
  final accounts = <Map<String, dynamic>>[].obs;
  final selectedAccountUrl = ''.obs; // 改用 URL 作为唯一标识

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList('accounts') ?? [];
    final activeUrl = prefs.getString('activeAccount');

    accounts.value = accountsJson.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    if (accounts.isNotEmpty) {
      selectedAccountUrl.value = activeUrl ?? accounts.first['url'];
    }
  }

  Future<void> selectAccount(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeAccount', url);
      selectedAccountUrl.value = url;

      // 找到对应的账户信息
      final account = accounts.firstWhere((acc) => acc['url'] == url);
      // 切换存储服务
      await Get.find<HomeLogic>().switchStorageService(account);

      Get.snackbar('成功', '已切换同步账户');
    } catch (e) {
      print('切换账户失败: $e');
      Get.snackbar('错误', '切换账户失败：$e');
    }
  }
}

class SyncDrawer extends StatelessWidget {
  const SyncDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SyncDrawerController());
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.primaryColor,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.onPrimary,
                  child: Icon(
                    Icons.cloud_sync,
                    size: 30,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '媒体同步',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '轻松同步您的照片和视频',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() => ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '同步账户',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...controller.accounts.map((account) => _buildAccountTile(
                          context,
                          account,
                          isSelected: controller.selectedAccountUrl.value == account['url'],
                          onTap: () => controller.selectAccount(account['url']),
                        )),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('添加账户'),
                      onTap: () {
                        // Get.back();
                        Get.toNamed(Routes.addAccountPage);
                      },
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, Map<String, dynamic> account,
      {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(
        Icons.cloud,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        account['name'] ?? '未命名账户',
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(account['url'] ?? ''),
      selected: isSelected,
      onTap: onTap,
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
    );
  }
}
