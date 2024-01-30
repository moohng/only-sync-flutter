import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class SyncDrawer extends StatelessWidget {
  const SyncDrawer({super.key});

  final accountList = const [
    AccountInfo(name: 'SMB', icon: Icons.lan_outlined, selectedIcon: Icons.lan),
    AccountInfo(name: 'WebDAV', icon: Icons.cloud_outlined, selectedIcon: Icons.cloud),
  ];

  final syncList = const [
    SyncInfo(name: '相册同步', icon: Icons.image_outlined, selectedIcon: Icons.image),
    SyncInfo(name: '视频同步', icon: Icons.video_file_outlined, selectedIcon: Icons.video_file),
  ];

  @override
  Widget build(BuildContext context) {
    // final HomeLogic homeLogic = Get.find();
    return GetX<HomeLogic>(
        builder: (homeLogic) => NavigationDrawer(
              onDestinationSelected: (value) {
                log('选择了：$value');
                homeLogic.changePage(value);
              },
              selectedIndex: homeLogic.pageIndex.value,
              children: [
                const DrawerHeader(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Only Sync',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 15, 30, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('账户'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          // 去添加存储账户
                          log('添加存储账户');
                        },
                      ),
                    ],
                  ),
                ),
                const NavigationDrawerDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: Text(
                    '本地存储',
                    style: TextStyle(fontSize: 16),
                  ),
                  selectedIcon: Icon(Icons.folder),
                  backgroundColor: Colors.redAccent,
                ),
                ...accountList
                    .map((account) => NavigationDrawerDestination(
                          icon: Icon(account.icon),
                          label: Text(
                            account.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                          selectedIcon: Icon(account.selectedIcon),
                        ))
                    .toList(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 15, 30, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('同步'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          // 创建同步
                          log('创建同步');
                        },
                      ),
                    ],
                  ),
                ),
                ...syncList
                    .map((sync) => NavigationDrawerDestination(
                          icon: Icon(sync.icon),
                          label: Text(
                            sync.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                          selectedIcon: Icon(sync.selectedIcon),
                        ))
                    .toList(),
              ],
            ));
  }
}
