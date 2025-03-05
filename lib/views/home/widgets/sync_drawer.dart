import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';

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
  final selectedAccountId = ''.obs; // 改用 URL 作为唯一标识

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList('accounts') ?? [];
    final activeId = prefs.getString('activeAccount');

    accounts.value = accountsJson.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    if (accounts.isNotEmpty) {
      selectedAccountId.value = activeId ?? accounts.first['id'];
    }
  }

  Future<void> selectAccount(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeAccount', id);
      selectedAccountId.value = id;

      // 找到对应的账户信息
      final account = accounts.firstWhere((acc) => acc['id'] == id);
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
                          isSelected: controller.selectedAccountId.value == account['id'],
                          onTap: () => controller.selectAccount(account['id']),
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
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(
                Icons.cloud,
                color: isSelected ? theme.primaryColor : theme.iconTheme.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['name']?.isEmpty ? '未命名账户' : account['name'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected ? theme.primaryColor : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account['url'] ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Get.toNamed(
                    Routes.addAccountPage,
                    arguments: account,
                  ),
                ),
                Icon(Icons.check, color: theme.primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
