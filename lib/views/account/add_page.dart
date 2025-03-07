import 'dart:convert';
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

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(logic.isEditMode.value ? '编辑账户' : '添加账户')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            if (logic.isEditMode.value) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除账户'),
                    content: const Text('确定要删除此账户吗？此操作不可恢复。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          logic.deleteAccount();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox();
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: logic.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('服务信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: logic.nameController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV 服务名称',
                  hintText: '请输入账户名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: logic.hostController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV 地址',
                  hintText: '例如：https://dav.example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 WebDAV 地址';
                  }
                  if (!value.startsWith('http')) {
                    return '请输入正确的 URL 地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: logic.pathController,
                decoration: const InputDecoration(
                  labelText: '远程路径',
                  hintText: '可选，例如：/myFolder',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('认证信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: logic.usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '请输入用户名（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: logic.passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码（可选）',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => FilledButton(
                          onPressed: logic.isLoading.value ? null : logic.testConnection,
                          child: logic.isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('测试连接'),
                        )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => FilledButton(
                          onPressed: logic.isLoading.value ? null : logic.saveAccount,
                          child: logic.isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('保存'),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => logic.showQRCode(context),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('生成账户二维码'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
