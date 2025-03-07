import 'package:get/get.dart';
import 'package:only_sync_flutter/views/account/add_page.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';
import 'package:only_sync_flutter/views/scan/scan_page.dart';

class Routes {
  static const String homePage = '/';
  static const String addAccountPage = '/add_account';
  static const String addSyncPage = '/add_sync';
  static const String scanPage = '/scan';

  static List<GetPage> getPages() {
    return [
      GetPage(
        name: homePage,
        page: () => const HomePage(),
        transition: Transition.fade,
      ),
      GetPage(
        name: addAccountPage,
        page: () => const AddAccountPage(),
        transition: Transition.rightToLeft,
      ),
      GetPage(
        name: addSyncPage,
        page: () => const AddAccountPage(),
        transition: Transition.rightToLeft,
      ),
      GetPage(
        name: scanPage,
        page: () => const ScanPage(),
        transition: Transition.rightToLeft,
      ),
    ];
  }
}
