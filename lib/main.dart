import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:only_sync_flutter/routes/route.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Only Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey.shade200),
        useMaterial3: true,
      ),
      initialRoute: Routes.homePage,
      getPages: Routes.getPages(),
    );
  }
}
