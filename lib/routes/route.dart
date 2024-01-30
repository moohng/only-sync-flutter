import 'package:get/get.dart';
import 'package:only_sync_flutter/views/account/add_page.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';

class Routes {
  static const String homePage = '/';
  static const String addAccountPage = '/add_account';
  static const String addSyncPage = '/add_sync';

  static List<GetPage> getPages() {
    return [
      GetPage(
        name: homePage,
        page: () => const HomePage(),
      ),
      GetPage(
        name: addAccountPage,
        page: () => const AddAccountPage(),
      ),
      GetPage(
        name: addSyncPage,
        page: () => const AddAccountPage(),
      ),
    ];
  }
}
