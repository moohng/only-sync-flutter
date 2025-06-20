import 'package:get/get.dart';
import 'package:only_sync_flutter/views/account/add_page.dart';
import 'package:only_sync_flutter/views/home/home_page.dart';
import 'package:only_sync_flutter/views/scan/scan_page.dart';
import 'package:only_sync_flutter/views/sync/sync_page.dart';
import 'package:only_sync_flutter/views/settings/settings_page.dart';

class Routes {
  static const String homePage = '/';
  static const String addAccountPage = '/add_account';
  static const String scanPage = '/scan';
  static const String syncPage = '/sync';
  static const String settingsPage = '/settings';

  static List<GetPage> getPages() {
    return [
      GetPage(name: homePage, page: () => const HomePage()),
      GetPage(name: addAccountPage, page: () => const AddAccountPage()),
      GetPage(name: scanPage, page: () => const ScanPage()),
      GetPage(name: syncPage, page: () => const SyncPage()),
      GetPage(name: settingsPage, page: () => const SettingsPage()),
    ];
  }
}
