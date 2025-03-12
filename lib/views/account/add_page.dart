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

    final formFields = [
      FormFieldConfig(
        label: '服务器地址',
        hint: 'https://example.com/webdav',
        controller: logic.hostController,
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return '请输入服务器地址';
          }
          if (!value!.startsWith('http')) {
            return '请输入有效的URL地址';
          }
          return null;
        },
      ),
      FormFieldConfig(
        label: '用户名',
        hint: '请输入用户名',
        controller: logic.usernameController,
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return '请输入用户名';
          }
          return null;
        },
      ),
      FormFieldConfig(
        label: '密码',
        hint: '请输入密码',
        controller: logic.passwordController,
        obscureText: true,
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return '请输入密码';
          }
          return null;
        },
      ),
      FormFieldConfig(
        label: '同步目录',
        hint: '/photos',
        controller: logic.pathController,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F6),
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.blue,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'WebDAV 配置',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(Routes.scanPage),
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
          ),
          IconButton(
            onPressed: () => logic.showQRCode(context),
            icon: const Icon(Icons.grid_view_rounded, color: Colors.blue),
          ),
        ],
      ),
      body: Form(
        key: logic.formKey,
        child: ListView(
          children: [
            // 表单卡片
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // 表单字段
                  ...formFields.map((field) => _FormField(config: field)),
                  const SizedBox(height: 16),
                  // 按钮
                  _ActionButton(
                    label: '测试连接',
                    color: Colors.blue,
                    onPressed: logic.testConnection,
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    label: '保存配置',
                    color: Colors.green,
                    onPressed: logic.saveAccount,
                  ),
                ],
              ),
            ),
            // 提示信息
            const _TipCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// 表单字段配置模型
class FormFieldConfig {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;

  FormFieldConfig({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.validator,
  });
}

// 表单字段组件
class _FormField extends StatelessWidget {
  final FormFieldConfig config;

  const _FormField({required this.config});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            config.label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[900],
            ),
          ),
        ),
        TextFormField(
          controller: config.controller,
          obscureText: config.obscureText,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: config.hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xffe5e7eb))),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xffe5e7eb))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
            contentPadding: const EdgeInsets.all(8),
          ),
          validator: config.validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// 操作按钮组件
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(8),
        backgroundColor: color,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

// 提示卡片组件
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFfffbeb),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Colors.orange[700],
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '请确保您的 WebDAV 服务器支持 HTTPS 连接，并且服务器证书有效。建议使用强密码保护您的账户安全。',
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                color: Color(0xff4b5563),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
