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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              log('搜索');
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 0,
                child: Text('同步'),
              ),
              PopupMenuItem(
                value: 1,
                child: Text('扫一扫'),
              ),
              PopupMenuItem(
                value: 2,
                child: Text('添加'),
              ),
              PopupMenuItem(
                value: 3,
                child: Text('删除'),
              ),
            ],
            onSelected: (value) {
              log('选择了：$value');
            },
          )
        ],
        title: Obx(() => Text('首页${homeLogic.pageIndex}')),
      ),
      drawer: const SyncDrawer(),
      body: Column(
        children: [Text('本地文件目录${homeLogic.pageIndex}')],
      ),
    );
  }
}
