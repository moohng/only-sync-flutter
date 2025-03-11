import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';

class SettingsController extends GetxController {
  final isWifiOnly = true.obs;
  final isOriginalUpload = false.obs;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final theme = Theme.of(context);

    return Scaffold(
      // backgroundColor: Colors.grey[100],
      backgroundColor: const Color.fromARGB(255, 242, 244, 246),
      appBar: AppBar(
        title: const Text('设置'),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        toolbarHeight: 64,
        // backgroundColor: const Color.fromARGB(255, 242, 244, 246),
      ),
      body: ListView(
        children: [
          // 同步设置组
          _buildSettingsGroup(
            theme,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud, color: Colors.blue),
                title: const Text('WebDAV 配置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.addAccountPage),
              ),
              Obx(() => SwitchListTile(
                    secondary: const Icon(Icons.wifi, color: Colors.green),
                    title: const Text('仅 Wi-Fi 下同步'),
                    value: controller.isWifiOnly.value,
                    onChanged: (value) => controller.isWifiOnly.value = value,
                  )),
              Obx(() => SwitchListTile(
                    secondary: const Icon(Icons.image, color: Colors.purple),
                    title: const Text('原图上传'),
                    value: controller.isOriginalUpload.value,
                    onChanged: (value) => controller.isOriginalUpload.value = value,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          // 其他设置组
          _buildSettingsGroup(
            theme,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('关于'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '版本 1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  // TODO: 显示关于页面
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
      ),
      child: Column(
        children: List.generate(
          children.length * 2 - 1,
          (index) {
            if (index.isOdd) {
              return Divider(
                height: .5,
                indent: 0,
                color: theme.dividerColor,
              );
            }
            return children[index ~/ 2];
          },
        ),
      ),
    );
  }
}
