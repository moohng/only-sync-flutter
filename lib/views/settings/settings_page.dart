import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';

class SettingsController extends GetxController {
  final isWifiOnly = true.obs;
  final isOriginalUpload = false.obs;
  final isLowBatteryPause = true.obs;
  final isNightSync = false.obs;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final theme = Theme.of(context);

    // 定义统一的开关样式
    final switchStyle = SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white; // 开启状态下的圆形按钮颜色
      }
      return Colors.white; // 关闭状态下的圆形按钮颜色
    }), trackColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.green; // 开启状态下的轨道颜色
      }
      return Colors.grey.withOpacity(0.3); // 关闭状态下的轨道颜色
    }), trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      return Colors.transparent;
    }));

    return Theme(
      data: Theme.of(context).copyWith(
        switchTheme: switchStyle,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F6), // 与原型保持一致的背景色
        appBar: AppBar(
          title: const Text('设置'),
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: const Color(0xFFF2F4F6),
          elevation: 0,
          toolbarHeight: 64,
        ),
        body: ListView(
          children: [
            const SizedBox(height: 16),
            // 云存储服务组
            _buildSettingsGroup(
              theme,
              children: [
                // _buildGroupHeader(theme, '云存储服务'),
                ListTile(
                  leading: const Icon(Icons.cloud, color: Colors.blue, size: 22),
                  title: const Text('WebDAV'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '已连接',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                  onTap: () => Get.toNamed(Routes.addAccountPage),
                ),
                // ListTile(
                //   leading: const Icon(Icons.cloud, color: Colors.blue, size: 22),
                //   title: const Text('Dropbox'),
                //   trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                //   onTap: () {
                //     // TODO: 添加Dropbox配置页面
                //   },
                // ),
                // ListTile(
                //   leading: const Icon(Icons.cloud, color: Colors.amber, size: 22),
                //   title: const Text('Google Drive'),
                //   trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                //   onTap: () {
                //     // TODO: 添加Google Drive配置页面
                //   },
                // ),
              ],
            ),
            const SizedBox(height: 16),

            // 同步策略组
            _buildSettingsGroup(
              theme,
              children: [
                // _buildGroupHeader(theme, '同步策略'),
                Obx(() => SwitchListTile(
                      secondary: const Icon(Icons.wifi, color: Colors.green, size: 22),
                      title: const Text('仅 Wi-Fi 下同步'),
                      value: controller.isWifiOnly.value,
                      onChanged: (value) => controller.isWifiOnly.value = value,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    )),
                Obx(() => SwitchListTile(
                      secondary: const Icon(Icons.battery_alert, color: Colors.orange, size: 22),
                      title: const Text('低电量时暂停同步'),
                      value: controller.isLowBatteryPause.value,
                      onChanged: (value) => controller.isLowBatteryPause.value = value,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    )),
                Obx(() => SwitchListTile(
                      secondary: const Icon(Icons.nightlight_round, color: Colors.indigo, size: 22),
                      title: const Text('夜间自动同步'),
                      value: controller.isNightSync.value,
                      onChanged: (value) => controller.isNightSync.value = value,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    )),
                Obx(() => SwitchListTile(
                      secondary: const Icon(Icons.image, color: Colors.purple, size: 22),
                      title: const Text('原图上传'),
                      value: controller.isOriginalUpload.value,
                      onChanged: (value) => controller.isOriginalUpload.value = value,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    )),
              ],
            ),
            const SizedBox(height: 16),

            // 其他设置组
            _buildSettingsGroup(
              theme,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue, size: 22),
                  title: const Text('关于'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '版本 1.0.0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
      ),
    );
  }

  Widget _buildSettingsGroup(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(0), // 移除圆角
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          children.length * 2 - 1,
          (index) {
            if (index.isOdd) {
              return Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withOpacity(0.5),
              );
            }
            return children[index ~/ 2];
          },
        ),
      ),
    );
  }

  Widget _buildGroupHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          // fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
