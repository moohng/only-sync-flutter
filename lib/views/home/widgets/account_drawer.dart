import 'package:flutter/material.dart';

class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      children: [
        Padding(
          padding: EdgeInsets.all(10),
        )
      ],
    );
  }
}
