import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStore extends GetxController {
  static AppStore get to => Get.find();

  // 当前服务
  final currentServiceId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentService();
  }

  Future<void> _loadCurrentService() async {
    final prefs = await SharedPreferences.getInstance();
    currentServiceId.value = prefs.getString('activeAccount') ?? '';
  }

  // 更新服务
  Future<void> updateService(String serviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeAccount', serviceId);
    currentServiceId.value = serviceId;
  }
}
