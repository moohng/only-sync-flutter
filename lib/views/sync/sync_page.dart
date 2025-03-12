import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';

class SyncController extends GetxController {
  final hasConfig = true.obs;
  final syncTasks = <Map<String, dynamic>>[].obs;
  final selectedTaskId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // 模拟加载任务数据
    syncTasks.value = [
      {
        'id': 'camera',
        'name': '相机胶卷',
        'icon': Icons.camera_alt,
        'status': 'syncing',
        'progress': 0.75,
        'total': 1000,
        'synced': 750,
      },
      {
        'id': 'favorites',
        'name': '我的收藏',
        'icon': Icons.favorite,
        'status': 'paused',
        'progress': 0.27,
        'total': 156,
        'synced': 42,
      },
    ];
  }

  void pauseTask(String taskId) {
    final index = syncTasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      syncTasks[index]['status'] = 'paused';
      syncTasks.refresh();
    }
  }

  void resumeTask(String taskId) {
    final index = syncTasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      syncTasks[index]['status'] = 'syncing';
      syncTasks.refresh();
    }
  }

  Future<void> deleteTask(String taskId) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除同步任务'),
        content: const Text('删除任务将停止同步，但不会删除已同步的照片。确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: Get.theme.colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      syncTasks.removeWhere((task) => task['id'] == taskId);
    }
  }

  void showAddTaskDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('添加同步任务', style: Get.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTaskOption(
              icon: Icons.camera_alt,
              iconColor: Colors.blue,
              title: '相机胶卷',
              subtitle: '同步所有相机拍摄的照片',
              onTap: () {
                // TODO: 实现添加相机胶卷同步任务
                Get.back();
              },
            ),
            const SizedBox(height: 8),
            _buildTaskOption(
              icon: Icons.folder,
              iconColor: Colors.amber,
              title: '选择相册',
              subtitle: '选择一个或多个相册进行同步',
              onTap: () {
                // TODO: 实现选择相册同步任务
                Get.back();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SyncController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text('同步'),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: const Color(0xFFF2F4F6),
        elevation: 0,
        toolbarHeight: 64,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.cloud_outlined, color: Colors.blue),
        //     onPressed: () => Get.toNamed(Routes.webdavBrowser),
        //   ),
        // ],
      ),
      body: Obx(() {
        if (controller.syncTasks.isEmpty) {
          return _buildEmptyState(theme);
        }
        return _buildSyncTasks(controller);
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.showAddTaskDialog,
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 64,
            color: theme.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无同步任务',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加同步任务',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTasks(SyncController controller) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.syncTasks.length,
      itemBuilder: (context, index) {
        final task = controller.syncTasks[index];
        return _SyncTaskCard(
          task: task,
          onPause: () => controller.pauseTask(task['id']),
          onResume: () => controller.resumeTask(task['id']),
          onDelete: () => controller.deleteTask(task['id']),
        );
      },
    );
  }
}

class _SyncTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _SyncTaskCard({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSyncing = task['status'] == 'syncing';
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isSyncing ? const Color(0xFFEBF3FF) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task['icon'] as IconData,
                  color: isSyncing ? Colors.blue : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  task['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 20,
                  ),
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (context) => [
                    if (isSyncing)
                      PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: const [
                            Icon(Icons.pause, size: 20),
                            SizedBox(width: 12),
                            Text('暂停同步'),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'resume',
                        child: Row(
                          children: const [
                            Icon(Icons.play_arrow, size: 20),
                            SizedBox(width: 12),
                            Text('继续同步'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: theme.colorScheme.error, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '删除任务',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'pause':
                        onPause();
                        break;
                      case 'resume':
                        onResume();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                ),
              ],
            ),
            if (isSyncing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task['progress'] as double,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(task['progress'] * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              isSyncing
                  ? '已同步 ${task['synced']}/${task['total']} 张照片'
                  : '已暂停 - 已同步 ${task['synced']}/${task['total']} 张照片',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
