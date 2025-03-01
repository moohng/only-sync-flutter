import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';
import 'package:only_sync_flutter/views/home/widgets/sync_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddAccountLogic extends GetxController {
  final selectedType = 'SMB'.obs;
  final isLoading = false.obs;
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final hostController = TextEditingController();
  final portController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final pathController = TextEditingController();

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

  Future<void> saveAccount() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final service = _createStorageService();
      await service.testConnection();

      // 保存账户信息
      final prefs = await SharedPreferences.getInstance();
      final accounts = prefs.getStringList('accounts') ?? [];

      final accountMap = {
        'type': 'WebDAV',
        'name': nameController.text,
        'url': hostController.text,
        'username': usernameController.text,
        'password': passwordController.text,
        'path': pathController.text,
      };

      accounts.add(jsonEncode(accountMap));
      await prefs.setStringList('accounts', accounts);

      // 设置为当前活跃账户
      await prefs.setString('activeAccount', hostController.text);

      Get.find<SyncDrawerController>().loadAccounts();
      Get.back();
      Get.snackbar('成功', '账户添加成功并已启用');
    } catch (e) {
      Get.snackbar('错误', '保存失败：$e');
    } finally {
      isLoading.value = false;
    }
  }

  StorageService _createStorageService() {
    final name = nameController.text;
    final host = hostController.text;
    // final port = int.parse(portController.text);
    final username = usernameController.text;
    final password = passwordController.text;
    // final path = pathController.text;
    return WebDAVService(
      name: name,
      url: host,
      username: username,
      password: password,
    );
    // return selectedType.value == 'SMB'
    //     ? SMBService(
    //         name: name,
    //         host: host,
    //         port: port,
    //         username: username,
    //         password: password,
    //         path: path,
    //       )
    //     : WebDAVService(
    //         name: name,
    //         host: host,
    //         port: port,
    //         username: username,
    //         password: password,
    //         path: path,
    //       );
  }

  @override
  void onInit() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    try {
      // 转换为Map<String, dynamic>
      Map<String, dynamic> account = jsonDecode(accounts.last);
      selectedType.value = account['type'] ?? selectedType.value;
      nameController.text = account['name'] ?? '';
      hostController.text = account['url'] ?? '';
      portController.text = account['port'].toString();
      usernameController.text = account['username'] ?? '';
      passwordController.text = account['password'] ?? '';
      pathController.text = account['path'] ?? '';
    } catch (e) {
      //
    }
    super.onInit();
  }

  @override
  void onClose() {
    nameController.dispose();
    hostController.dispose();
    portController.dispose();
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
        title: const Text('添加账户'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入账户名称';
                  }
                  return null;
                },
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
                controller: logic.portController,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '请输入端口号',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: logic.pathController,
                decoration: const InputDecoration(
                  labelText: '远程路径',
                  hintText: '请输入远程路径（可选）',
                  border: OutlineInputBorder(),
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}
