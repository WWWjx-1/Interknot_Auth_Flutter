/// AES-GCM 加解密单元测试
///
/// 验证 AES-GCM 加解密结果正确，格式与原 Python `SecurityManager` 一致
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interknot_auth_flutter/core/crypto/aes_gcm_crypto.dart';

void main() {
  group('AesGcmCrypto', () {
    late AesGcmCrypto aesGcm;

    setUp(() {
      // 使用 SHA256("test_key" + "InterKnot2026") 派生 32 字节密钥
      final rawKey = 'test_machine_guidInterKnot2026';
      final key = Uint8List.fromList(
        sha256.convert(utf8.encode(rawKey)).bytes,
      );
      aesGcm = AesGcmCrypto(key);
    });

    test('加密后可以正确解密', () {
      const plaintext = 'my_secret_password';
      final encrypted = aesGcm.encrypt(plaintext);
      final decrypted = aesGcm.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('加密输出为 base64 格式', () {
      const plaintext = 'hello';
      final encrypted = aesGcm.encrypt(plaintext);
      // base64 格式验证：尝试解码不抛出异常
      final decoded = base64.decode(encrypted);
      expect(decoded.length, greaterThan(16)); // nonce + ciphertext + tag
    });

    test('相同明文产生不同密文（随机 nonce）', () {
      const plaintext = 'same_password';
      final encrypted1 = aesGcm.encrypt(plaintext);
      final encrypted2 = aesGcm.encrypt(plaintext);
      expect(encrypted1, isNot(equals(encrypted2)));
      // 但都能正确解密
      expect(aesGcm.decrypt(encrypted1), equals(plaintext));
      expect(aesGcm.decrypt(encrypted2), equals(plaintext));
    });

    test('解密被篡改的密文应抛出异常', () {
      const plaintext = 'password';
      final encrypted = aesGcm.encrypt(plaintext);
      // 篡改密文（修改最后一个字符）
      final tampered = encrypted.substring(0, encrypted.length - 1) +
          (encrypted[encrypted.length - 1] == 'A' ? 'B' : 'A');
      expect(
        () => aesGcm.decrypt(tampered),
        throwsA(isA<Exception>()),
      );
    });

    test('加密空字符串', () {
      final encrypted = aesGcm.encrypt('');
      final decrypted = aesGcm.decrypt(encrypted);
      expect(decrypted, equals(''));
    });

    test('加密中文内容', () {
      const plaintext = '中文密码测试';
      final encrypted = aesGcm.encrypt(plaintext);
      final decrypted = aesGcm.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('密钥长度不为 32 时抛出异常', () {
      expect(
        () => AesGcmCrypto(Uint8List(16)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AesGcmCrypto(Uint8List(64)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('解密过短的密文抛出异常', () {
      expect(
        () => aesGcm.decrypt(base64.encode(Uint8List(10))),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
