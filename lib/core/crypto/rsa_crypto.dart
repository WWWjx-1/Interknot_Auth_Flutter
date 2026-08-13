/// RSA PKCS#1 v1.5 加密工具
///
/// 对应原 Python `Login_Thread.encrypt_rsa`：
/// - 公钥：1024 位 RSA，PKCS#1 PEM 格式，指数 65537
/// - 填充：PKCS#1 v1.5
/// - 输出：hex 编码的密文字符串
///
/// 验证标准：与 Python `rsa.encrypt(message, pub_key)` + `binascii.hexlify()` 输出字节级一致
library;

import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

/// RSA 加密器（PKCS#1 v1.5 填充，hex 输出）
///
/// 使用 `encrypt` 包（基于 pointycastle）实现 RSA PKCS#1 v1.5 加密。
class RsaCrypto {
  final RSAPublicKey _publicKey;
  final Encrypter _encrypter;

  /// 从 PEM 格式公钥字符串构造
  ///
  /// [pemKey] 格式：-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----
  factory RsaCrypto.fromPem(String pemKey) {
    final parser = RSAKeyParser();
    final key = parser.parse(pemKey) as RSAPublicKey;
    final rsa = RSA(publicKey: key);
    final encrypter = Encrypter(rsa);
    return RsaCrypto._(key, encrypter);
  }

  RsaCrypto._(this._publicKey, this._encrypter);

  /// 公钥模数 n 的字节长度
  int get keySizeInBytes {
    final n = _publicKey.n;
    if (n == null) return 128;
    return (n.bitLength + 7) ~/ 8;
  }

  /// PKCS#1 v1.5 最大可加密长度 = keySizeInBytes - 11
  int get maxEncryptLength => keySizeInBytes - 11;

  /// 使用 RSA PKCS#1 v1.5 加密明文，返回 hex 字符串
  ///
  /// [plaintext] 待加密字符串（UTF-8 编码后加密）
  ///
  /// 若明文超出 [maxEncryptLength] 字节，抛出 [ArgumentError]
  String encryptHex(String plaintext) {
    final bytes = utf8.encode(plaintext);
    if (bytes.length > maxEncryptLength) {
      throw ArgumentError(
        '明文过长：${bytes.length} > $maxEncryptLength 字节',
      );
    }
    // encrypt 包默认使用 PKCS#1 v1.5 填充
    final encrypted = _encrypter.encryptBytes(bytes);
    return _bytesToHex(encrypted.bytes);
  }

  /// 字节数组转 hex 字符串（小写，与原 Python binascii.hexlify 一致）
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
