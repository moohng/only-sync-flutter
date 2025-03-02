import 'package:get/get.dart';

class AppStore extends GetxController {
  static AppStore get to => Get.find();

  // 全局服务可用性状态
  final isServiceAvailable = false.obs;

  // 更新服务状态
  void updateServiceStatus(bool status) {
    isServiceAvailable.value = status;
  }
}
