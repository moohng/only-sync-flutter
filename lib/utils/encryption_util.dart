import 'package:encrypt/encrypt.dart';

class EncryptionUtil {
  static final _key = Key.fromLength(32); // AES-256
  static final _iv = IV.fromLength(16);
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
      print('解密失败: $e');
      return '';
    }
  }
}
