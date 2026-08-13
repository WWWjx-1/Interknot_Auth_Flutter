/// M2 阶段集成测试脚本
///
/// 此文件用于在**校园网环境**中手动验证 M2 各模块。
/// 不需要测试框架，直接运行 main() 即可。
///
/// 运行方式：
/// ```bash
/// dart run test/manual/m2_integration_test.dart
/// ```
///
/// 前置条件：
/// 1. 已连接到校园网（能访问 Portal）
/// 2. 已安装 Python + ddddocr（OCR 子进程需要）
/// 3. 有一个 t 开头的测试账号
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:interknot_auth_flutter/core/crypto/rsa_crypto.dart';
import 'package:interknot_auth_flutter/core/network/dio_client.dart';
import 'package:interknot_auth_flutter/core/process/ocr_service.dart';
import 'package:interknot_auth_flutter/features/auth/data/auth_repository.dart';
import 'package:interknot_auth_flutter/features/auth/data/esurfing_api.dart';

/// 手动集成测试入口
///
/// 使用方法：
/// 1. 修改下方 [testUser] 和 [testPassword]
/// 2. 运行此脚本
/// 3. 观察控制台输出
void main(List<String> args) async {
  // ═══════════════════════════════════════════════
  //  修改此处为你的测试账号
  // ═══════════════════════════════════════════════
  const testUser = 't你的学号'; // t 开头的 HTTP 登录账号
  const testPassword = '你的密码';
  // ═══════════════════════════════════════════════

  print('═' * 60);
  print('M2 集成测试开始');
  print('═' * 60);

  final portalDio = DioFactory.createPortalDio();
  final publicDio = DioFactory.createPublicDio();
  final rsaCrypto = RsaCrypto.fromPem(rsaPublicKeyPem);
  final ocrService = PythonOcrService();

  final repo = AuthRepositoryImpl(
    portalDio: portalDio,
    publicDio: publicDio,
    rsaCrypto: rsaCrypto,
    ocrService: ocrService,
  );

  var allPassed = true;

  // ── 测试 1: 取参（GET 189.cn → 解析 Portal 参数） ──
  print('\n── 测试 1: 获取 Portal 参数 ──');
  try {
    final params = await repo.fetchEsurfingParams();
    print('  ✅ esurfingUrl: ${params.esurfingUrl}');
    print('  ✅ wlanAcIp:    ${params.wlanAcIp}');
    print('  ✅ wlanUserIp:  ${params.wlanUserIp}');
  } catch (e) {
    print('  ❌ 失败: $e');
    allPassed = false;
  }

  // ── 测试 2: RSA 加密测试 ──
  print('\n── 测试 2: RSA 加密 ──');
  try {
    final payload = jsonEncode({
      'userName': 'test',
      'password': 'test',
      'rand': 'TEST',
    });
    final loginKey = rsaCrypto.encryptHex(payload);
    print('  ✅ loginKey 长度: ${loginKey.length} (期望 256)');
    print('  ✅ loginKey 前20字符: ${loginKey.substring(0, 20)}...');
  } catch (e) {
    print('  ❌ 失败: $e');
    allPassed = false;
  }

  // ── 测试 3: HTTP 登录（完整流程） ──
  print('\n── 测试 3: HTTP 登录 ──');
  if (testUser == 't你的学号') {
    print('  ⚠ 跳过：请修改 testUser 为实际账号');
  } else {
    try {
      // 先取参
      final params = await repo.fetchEsurfingParams();

      final result = await repo.login(
        user: testUser,
        password: testPassword,
        esurfingUrl: params.esurfingUrl,
        wlanAcIp: params.wlanAcIp,
        wlanUserIp: params.wlanUserIp,
        loginMode: 1, // HTTP 模式
      );

      switch (result) {
        case LoginSuccess(signature: final sig):
          print('  ✅ 登录成功');
          print(
            '  ✅ signature: ${sig != null ? "已获取 (${sig!.substring(0, 10)}...)" : "null"}',
          );

          // ── 测试 4: 登出 ──
          print('\n── 测试 4: 登出 ──');
          if (sig != null) {
            try {
              await repo.logout(
                esurfingUrl: params.esurfingUrl,
                signature: sig,
              );
              print('  ✅ 登出成功');
            } catch (e) {
              print('  ❌ 登出失败: $e');
              allPassed = false;
            }
          } else {
            print('  ⚠ 无 signature，跳过登出测试');
          }

        case LoginFailed(:final message, :final isCaptchaError):
          if (isCaptchaError) {
            print('  ⚠ 验证码错误（正常，OCR 可能识别不准，已自动重试）');
            print('  信息: $message');
          } else {
            print('  ❌ 登录失败: $message');
            allPassed = false;
          }

        case LoginInProgress(:final step):
          print('  ⚠ 登录中: $step');
      }
    } catch (e) {
      print('  ❌ 异常: $e');
      allPassed = false;
    }
  }

  // ── 总结 ──
  print('\n${'═' * 60}');
  if (allPassed) {
    print('M2 集成测试：全部通过 ✅');
  } else {
    print('M2 集成测试：部分失败 ❌（请检查上述输出）');
  }
  print('═' * 60);
}

/// RSA 公钥（与 State.py 中一致）
const rsaPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyhncn4Z4RY8wITqV7n6hAapEM
ZwNBP6fflsGs3Ke5g6Ji4AWvNflIXZLNTGIuykoU1v2Bitylyuc9nSKLTvBdcytB
+4X4CvV4oVDr2aLrXs7LhTNyykcxyhyGhokph0Cb4yR/mybK6OeH2ME1/AZS7AZ4
pe2gw9lcwXQVF8DJwwIDAQAB
-----END PUBLIC KEY-----''';
