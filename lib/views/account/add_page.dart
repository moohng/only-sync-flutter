import 'dart:developer';

import 'package:flutter/material.dart';

class AddAccountPage extends StatelessWidget {
  const AddAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('添加账户'),
        actions: [
          TextButton(
            child: Text('保存'),
            onPressed: () {
              log('保存');
            },
          )
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '账户名',
              hintText: '请输入账户名',
            ),
          ),
          TextField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
            ),
          ),
        ],
      ),
    );
  }
}
