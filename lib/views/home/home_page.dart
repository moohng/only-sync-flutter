import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';

class HomeLogic extends GetxController {
  var pageIndex = 0.obs;

  void changePage(int index) {
    pageIndex.value = index;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeLogic = Get.put(HomeLogic());

    return Scaffold(
      appBar: AppBar(
        actions: [
          Builder(builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu_open),
              onPressed: () {
                log('hello');
                Scaffold.of(context).openEndDrawer();
              },
            );
          }),
        ],
        title: Obx(() => Text('首页${homeLogic.pageIndex}')),
      ),
      endDrawer: SyncDrawer(),
      body: Column(
        children: [Text('本地文件目录${homeLogic.pageIndex}')],
      ),
    );
  }
}
