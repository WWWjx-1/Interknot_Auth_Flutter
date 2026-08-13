/// M2 认证仓库单元测试
///
/// 验证无需网络环境的核心逻辑：
/// - RSA 加密结果格式正确
/// - 189.cn URL 解析逻辑
/// - 验证码 URL 提取正则
/// - 登录结果判断逻辑
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:interknot_auth_flutter/core/crypto/rsa_crypto.dart';
import 'package:interknot_auth_flutter/features/auth/data/auth_dto.dart';
import 'package:interknot_auth_flutter/features/auth/data/esurfing_api.dart';

void main() {
  group('RsaCrypto', () {
    late RsaCrypto rsa;

    setUp(() {
      rsa = RsaCrypto.fromPem(rsaPublicKeyPem);
    });

    test('PEM 公钥解析成功', () {
      expect(rsa.keySizeInBytes, equals(128)); // 1024-bit = 128 bytes
      expect(rsa.maxEncryptLength, equals(117)); // 128 - 11(PKCS#1 v1.5)
    });

    test('RSA 加密输出为 hex 字符串', () {
      final result = rsa.encryptHex('test_message');
      // hex 字符串只包含 0-9a-f
      expect(result, isNot(isEmpty));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
      // 1024-bit RSA 加密结果应为 256 个 hex 字符（128 bytes）
      expect(result.length, equals(256));
    });

    test('超长明文抛出异常', () {
      final longText = 'A' * 118; // 超过 maxEncryptLength=117
      expect(
        () => rsa.encryptHex(longText),
        throwsArgumentError,
      );
    });

    test('JSON payload 加密', () {
      final payload = jsonEncode({
        'userName': 'testuser',
        'password': 'testpass',
        'rand': 'ABCD',
      });
      final result = rsa.encryptHex(payload);
      expect(result, isNot(isEmpty));
      expect(result.length, equals(256));
    });
  });

  group('EsurfingApi - 常量', () {
    test('登录成功码包含 0 和 13002000', () {
      expect(EsurfingApi.loginSuccessCodes, contains('0'));
      expect(EsurfingApi.loginSuccessCodes, contains('13002000'));
    });

    test('最大重试次数为 5', () {
      expect(EsurfingApi.maxCaptchaRetries, equals(5));
    });

    test('重试间隔为 3 秒', () {
      expect(EsurfingApi.captchaRetryIntervalSeconds, equals(3));
    });

    test('连通性检测有 6 个源', () {
      expect(EsurfingApi.connectivityCheckUrls.length, equals(6));
    });
  });

  group('EsurfingApi - 正则模式', () {
    test('提取 esurfingurl', () {
      const url = 'http://10.10.10.10:8080/qs/index_gz.jsp?wlanacip=1.2.3.4&wlanuserip=5.6.7.8';
      final match = EsurfingApi.esurfingUrlPattern.firstMatch(url);
      expect(match, isNotNull);
      expect(match!.group(1), equals('10.10.10.10:8080'));
    });

    test('提取 wlanacip', () {
      const url = 'http://example.com/path?wlanacip=192.168.1.1&wlanuserip=10.0.0.1';
      final match = EsurfingApi.wlanAcIpPattern.firstMatch(url);
      expect(match, isNotNull);
      expect(match!.group(1), equals('192.168.1.1'));
    });

    test('提取 wlanuserip', () {
      const url = 'http://example.com/path?wlanuserip=10.0.0.1';
      final match = EsurfingApi.wlanUserIpPattern.firstMatch(url);
      expect(match, isNotNull);
      expect(match!.group(1), equals('10.0.0.1'));
    });

    test('提取验证码图片 URL', () {
      const html = '''
        <html>
        <body>
          <img src="/common/image_code.jsp?time=1733123456789" />
        </body>
        </html>
      ''';
      final match = EsurfingApi.captchaImageUrlPattern.firstMatch(html);
      expect(match, isNotNull);
      expect(match!.group(0), contains('/common/image_code.jsp?time='));
    });
  });

  group('AuthDTO', () {
    test('LoginRequest toJson', () {
      final request = LoginRequest(
        userName: 't001',
        password: 'secret',
        rand: 'ABCD',
      );
      final json = request.toJson();
      expect(json['userName'], equals('t001'));
      expect(json['password'], equals('secret'));
      expect(json['rand'], equals('ABCD'));
    });

    test('LoginSuccess 带 signature', () {
      final result = LoginSuccess(signature: 'abc123');
      expect(result.signature, equals('abc123'));
    });

    test('LoginFailed 验证码错误标记', () {
      final result = LoginFailed(
        message: '验证码错误',
        isCaptchaError: true,
      );
      expect(result.isCaptchaError, isTrue);
      expect(result.isFatal, isFalse);
    });

    test('LoginFailed 致命错误标记', () {
      final result = LoginFailed(
        message: '密码错误',
        isFatal: true,
      );
      expect(result.isFatal, isTrue);
    });
  });
}

/// RSA 公钥（与 State.py 中一致）
const rsaPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyhncn4Z4RY8wITqV7n6hAapEM
ZwNBP6fflsGs3Ke5g6Ji4AWvNflIXZLNTGIuykoU1v2Bitylyuc9nSKLTvBdcytB
+4X4CvV4oVDr2aLrXs7LhTNyykcxyhyGhokph0Cb4yR/mybK6OeH2ME1/AZS7AZ4
pe2gw9lcwXQVF8DJwwIDAQAB
-----END PUBLIC KEY-----''';
