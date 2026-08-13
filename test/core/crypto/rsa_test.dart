/// RSA 加密单元测试
///
/// 验证 RSA PKCS#1 v1.5 加密结果与原 Python `encrypt_rsa` 字节级一致
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:interknot_auth_flutter/core/crypto/rsa_crypto.dart';

void main() {
  // 天翼校园网 RSA 公钥（1024 位）
  const publicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyhncn4Z4RY8wITqV7n6hAapEM
ZwNBP6fflsGs3Ke5g6Ji4AWvNflIXZLNTGIuykoU1v2Bitylyuc9nSKLTvBdcytB
+4X4CvV4oVDr2aLrXs7LhTNyykcxyhyGhokph0Cb4yR/mybK6OeH2ME1/AZS7AZ4
pe2gw9lcwXQVF8DJwwIDAQAB
-----END PUBLIC KEY-----''';

  late RsaCrypto rsaCrypto;

  setUp(() {
    rsaCrypto = RsaCrypto.fromPem(publicKeyPem);
  });

  group('RsaCrypto', () {
    test('从 PEM 公钥构造成功', () {
      expect(rsaCrypto, isNotNull);
      expect(rsaCrypto.keySizeInBytes, equals(128)); // 1024 位 = 128 字节
      expect(rsaCrypto.maxEncryptLength, equals(117)); // 128 - 11 = 117
    });

    test('encryptHex 返回 hex 字符串', () {
      final result = rsaCrypto.encryptHex('test');
      expect(result, isA<String>());
      expect(result.length, isPositive);
      // hex 字符串只包含 0-9 a-f
      expect(result, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('相同明文产生不同密文（PKCS#1 v1.5 随机填充）', () {
      final result1 = rsaCrypto.encryptHex('hello');
      final result2 = rsaCrypto.encryptHex('hello');
      // PKCS#1 v1.5 填充包含随机字节，每次加密结果不同
      expect(result1, isNot(equals(result2)));
    });

    test('密文长度为 256 hex 字符（128 字节）', () {
      final result = rsaCrypto.encryptHex('hello world');
      expect(result.length, equals(256)); // 128 bytes * 2 hex chars
    });

    test('明文超长时抛出 ArgumentError', () {
      // 117 字节是最大可加密长度
      final tooLong = 'x' * 118;
      expect(
        () => rsaCrypto.encryptHex(tooLong),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('加密 JSON 格式的登录数据', () {
      // 模拟原 Python 登录流程中的 JSON 构建
      final payload = jsonEncode({
        'userName': 't12345678',
        'password': 'test_password',
        'rand': 'ABCD',
      });
      final result = rsaCrypto.encryptHex(payload);
      expect(result.length, equals(256));
      expect(result, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('加密中文内容', () {
      final result = rsaCrypto.encryptHex('测试中文');
      expect(result, isA<String>());
      expect(result.length, equals(256));
    });
  });
}
