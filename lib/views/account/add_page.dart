import 'dart:convert';
import 'package:only_sync_flutter/routes/route.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddAccountLogic extends GetxController {
  final isLoading = false.obs;
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final hostController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final pathController = TextEditingController();

  final isEditMode = false.obs;
  String? editingId;

  Future<void> testConnection() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final service = _createStorageService();
      await service.testConnection();
      Get.snackbar('成功', '连接测试成功');
    } catch (e) {
      Get.snackbar('错误', '连接测试失败：$e');
    } finally {
      isLoading.value = false;
    }
  }

  // 生成包含账户信息的JSON字符串，用于二维码
  String generateAccountQRData() {
    final accountMap = {
      'type': 'WebDAV',
      'name': nameController.text,
      'url': hostController.text,
      'username': usernameController.text,
      'password': passwordController.text,
      'path': pathController.text,
    };
    return jsonEncode(accountMap);
  }

  // 显示二维码对话框
  void showQRCode(BuildContext context) {
    if (!formKey.currentState!.validate()) return;

    final qrData = generateAccountQRData();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('账户二维码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('扫描此二维码可自动添加账户'),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> saveAccount() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final service = _createStorageService();
      await service.testConnection();

      final prefs = await SharedPreferences.getInstance();
      final accounts = prefs.getStringList('accounts') ?? [];

      final accountMap = {
        'id': isEditMode.value ? editingId! : const Uuid().v4(),
        'type': 'WebDAV',
        'name': nameController.text,
        'url': hostController.text,
        'path': pathController.text,
        'username': usernameController.text,
        'password': passwordController.text,
      };

      if (isEditMode.value) {
        // 更新现有账户
        final index = accounts.indexWhere((json) {
          final acc = jsonDecode(json);
          return acc['id'] == editingId;
        });
        if (index != -1) {
          accounts[index] = jsonEncode(accountMap);
          await prefs.setStringList('accounts', accounts);

          // 如果编辑的是当前活跃账户，更新服务
          final activeId = prefs.getString('activeAccount');
          if (editingId == activeId) {
            await Get.find<HomeLogic>().switchStorageService(accountMap);
          }
        }
      } else {
        // 添加新账户
        accounts.add(jsonEncode(accountMap));
        await prefs.setStringList('accounts', accounts);
        await prefs.setString('activeAccount', accountMap['id']!);
        await Get.find<HomeLogic>().switchStorageService(accountMap);
      }

      Get.find<SyncDrawerController>().loadAccounts();
      Get.back();
      Get.snackbar('成功', isEditMode.value ? '账户已更新' : '账户添加成功并已启用');
    } catch (e) {
      Get.snackbar('错误', '保存失败：$e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteAccount() async {
    if (editingId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = prefs.getStringList('accounts') ?? [];

      // 从列表中移除账户
      final newAccounts = accounts.where((json) {
        final acc = jsonDecode(json);
        return acc['id'] != editingId && acc['url'] != editingId;
      }).toList();

      await prefs.setStringList('accounts', newAccounts);

      // 如果删除的是当前活跃账户，切换到第一个账户
      final activeId = prefs.getString('activeAccount');
      if (editingId == activeId) {
        if (newAccounts.isNotEmpty) {
          final firstAcc = jsonDecode(newAccounts.first);
          await prefs.setString('activeAccount', firstAcc['id']);
          Get.find<SyncDrawerController>().loadAccounts();
          await Get.find<HomeLogic>().switchStorageService(firstAcc);
        } else {
          await prefs.remove('activeAccount');
          Get.find<SyncDrawerController>().loadAccounts();
        }
      }

      Get.back();
      Get.snackbar('成功', '账户已删除');
    } catch (e) {
      Get.snackbar('错误', '删除失败：$e');
    }
  }

  RemoteStorageService _createStorageService() {
    final name = nameController.text;
    final host = hostController.text;
    final username = usernameController.text;
    final password = passwordController.text;
    final remoteBasePath = pathController.text;

    return WebDAVService(
      name: name,
      url: host,
      username: username,
      password: password,
      remoteBasePath: remoteBasePath,
    );
  }

  @override
  void onInit() async {
    // 检查是否传入了账户信息用于编辑或从二维码填充
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      // 如果没有 id，说明是从二维码来的数据
      if (!args.containsKey('id')) {
        nameController.text = args['name'] ?? '';
        hostController.text = args['url'] ?? '';
        usernameController.text = args['username'] ?? '';
        passwordController.text = args['password'] ?? '';
        pathController.text = args['path'] ?? '';
      } else {
        // 编辑模式
        isEditMode.value = true;
        editingId = args['id'];
        nameController.text = args['name'] ?? '';
        hostController.text = args['url'] ?? '';
        usernameController.text = args['username'] ?? '';
        passwordController.text = args['password'] ?? '';
        pathController.text = args['path'] ?? '';
      }
    }
    super.onInit();
  }

  @override
  void onClose() {
    nameController.dispose();
    hostController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    pathController.dispose();
    super.onClose();
  }
}

class AddAccountPage extends StatelessWidget {
  const AddAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(AddAccountLogic());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(logic.isEditMode.value ? '编辑账户' : 'WebDAV 配置')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => Get.toNamed(Routes.scanPage),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => logic.showQRCode(context),
          ),
          if (logic.isEditMode.value)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirm(context, logic),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: logic.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormGroup(
                theme,
                title: '服务器信息',
                children: [
                  _buildTextField(
                    controller: logic.hostController,
                    label: '服务器地址',
                    hint: 'https://example.com/webdav',
                    icon: Icons.link,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入服务器地址';
                      if (!value!.startsWith('http')) return '请输入正确的URL地址';
                      return null;
                    },
                  ),
                  _buildTextField(
                    controller: logic.pathController,
                    label: '同步目录',
                    hint: '/photos',
                    icon: Icons.folder_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFormGroup(
                theme,
                title: '认证信息',
                children: [
                  _buildTextField(
                    controller: logic.usernameController,
                    label: '用户名',
                    hint: '请输入用户名（可选）',
                    icon: Icons.person_outline,
                  ),
                  _buildTextField(
                    controller: logic.passwordController,
                    label: '密码',
                    hint: '请输入密码（可选）',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: logic.testConnection,
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('测试连接'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: logic.saveAccount,
                      icon: const Icon(Icons.save),
                      label: const Text('保存配置'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTipCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormGroup(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: List.generate(
              children.length * 2 - 1,
              (index) {
                if (index.isOdd) {
                  return const Divider(height: 1, indent: 56);
                }
                return children[index ~/ 2];
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: hint,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTipCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '请确保您的 WebDAV 服务器支持 HTTPS 协议，并使用有效的证书。数据传输过程中涉及的敏感信息将被加密。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, AddAccountLogic logic) {
    Get.dialog(
      AlertDialog(
        title: const Text('删除账户'),
        content: const Text('确定要删除此账户吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              logic.deleteAccount();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
