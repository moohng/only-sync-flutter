import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/core/storage/storage_service.dart';

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
      await service.saveAccount();
      Get.back();
      Get.snackbar('成功', '账户添加成功');
    } catch (e) {
      Get.snackbar('错误', '保存失败：$e');
    } finally {
      isLoading.value = false;
    }
  }

  StorageService _createStorageService() {
    final name = nameController.text;
    final host = hostController.text;
    final port = int.parse(portController.text);
    final username = usernameController.text;
    final password = passwordController.text;
    final path = pathController.text;
    return WebDAVService(
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      path: path,
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
              const Text('服务类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => RadioListTile(
                          title: const Text('SMB'),
                          subtitle: const Text('适用于局域网文件共享'),
                          value: 'SMB',
                          groupValue: logic.selectedType.value,
                          onChanged: (value) => logic.selectedType.value = value!,
                        )),
                  ),
                  Expanded(
                    child: Obx(() => RadioListTile(
                          title: const Text('WebDAV'),
                          subtitle: const Text('适用于远程网盘服务'),
                          value: 'WebDAV',
                          groupValue: logic.selectedType.value,
                          onChanged: (value) => logic.selectedType.value = value!,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: logic.nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称',
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
                  labelText: '服务器地址',
                  hintText: '请输入服务器IP或域名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入服务器地址';
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入端口号';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效的端口号';
                  }
                  return null;
                },
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
