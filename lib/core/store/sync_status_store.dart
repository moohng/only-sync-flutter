import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:only_sync_flutter/core/media/media_manager.dart';

class SyncStatusStore {
  static const String _syncStatusKey = 'sync_status';

  // 保存格式：Map<accountId, Map<imagePath, status>>
  late SharedPreferences _prefs;
  String? _currentAccountId;
  Map<String, SyncStatus> _statusCache = {};

  Future<void> init(String? accountId) async {
    _prefs = await SharedPreferences.getInstance();
    _currentAccountId = accountId;
    if (accountId != null) {
      _loadStatusFromPrefs(accountId);
    }
  }

  void _loadStatusFromPrefs(String accountId) {
    final rawData = _prefs.getString(_syncStatusKey) ?? '{}';
    final Map<String, dynamic> allData = json.decode(rawData);
    final Map<String, dynamic> accountData = allData[accountId] ?? {};

    _statusCache = accountData.map((key, value) => MapEntry(key, SyncStatus.values[value as int]));
  }

  Future<void> saveStatus(String path, SyncStatus status) async {
    if (_currentAccountId == null) return;

    _statusCache[path] = status;

    final rawData = _prefs.getString(_syncStatusKey) ?? '{}';
    final Map<String, dynamic> allData = json.decode(rawData);

    allData[_currentAccountId!] = _statusCache.map((key, value) => MapEntry(key, value.index));

    await _prefs.setString(_syncStatusKey, json.encode(allData));
  }

  SyncStatus getStatus(String path) {
    return _statusCache[path] ?? SyncStatus.notSynced;
  }

  void switchAccount(String accountId) {
    _currentAccountId = accountId;
    _loadStatusFromPrefs(accountId);
  }

  void clear() {
    _statusCache.clear();
    _currentAccountId = null;
  }
}
