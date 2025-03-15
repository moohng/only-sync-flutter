import 'package:get/get.dart';

class AppStore extends GetxController {
  static AppStore get to => Get.find();

  // 当前服务
  final currentServiceId = ''.obs;

  // 更新服务
  void updateService(String serviceId) {
    currentServiceId.value = serviceId;
  }
}
