import 'dart:developer';

import 'package:encrypt/encrypt.dart';

class EncryptionUtil {
  static final _key = Key.fromUtf8('ro94irjfh3gdf6r9ei7uy5kloijuyh56'); // AES-256
  static final _iv = IV.fromUtf8('aswe34rf51giujt5'); // 128位IV

  /// 初始化加密器
  static final _encrypter = Encrypter(AES(_key));

  /// 加密字符串
  static String encrypt(String text) {
    if (text.isEmpty) return '';
    final encrypted = _encrypter.encrypt(text, iv: _iv);
    return encrypted.base64;
  }

  /// 解密字符串
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      log('解密失败: $e');
      return '';
    }
  }
}
