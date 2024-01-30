import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';

class SyncDrawer extends StatelessWidget {
  const SyncDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // final HomeLogic homeLogic = Get.find();
    return GetX<HomeLogic>(
        builder: (homeLogic) => NavigationDrawer(
              onDestinationSelected: (value) {
                log('选择了：$value');
                homeLogic.changePage(value);
              },
              // indicatorColor: Colors.transparent,
              // indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              selectedIndex: homeLogic.pageIndex.value,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(30, 30, 30, 15),
                  child: Text('账号'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: Text('本地存储'),
                  selectedIcon: Icon(Icons.folder),
                  backgroundColor: Colors.redAccent,
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.lan_outlined),
                  label: Text('SMB'),
                  selectedIcon: Icon(Icons.lan),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.cloud_outlined),
                  label: Text('WEBDAV'),
                  selectedIcon: Icon(Icons.cloud),
                ),
                Divider(
                  indent: 15,
                  endIndent: 15,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                  child: Text('同步'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.photo_camera_back_outlined),
                  label: Text('相册同步'),
                  selectedIcon: Icon(Icons.photo_camera_back),
                  backgroundColor: Colors.redAccent,
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.lan_outlined),
                  label: Text('本地同步'),
                  selectedIcon: Icon(Icons.lan),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.video_collection_outlined),
                  label: Text('视频同步'),
                  selectedIcon: Icon(Icons.video_collection),
                ),
              ],
            ));
  }
}
