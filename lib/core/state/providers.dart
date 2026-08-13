/// 全局 Provider 汇总
///
/// 统一注册所有核心层 Provider，包括：
/// - Dio 实例
/// - 存储层（SecureAccountStore、ConfigStore、FileStore）
/// - 平台服务
/// - 加密组件
///
/// 所有 Provider 通过此文件集中管理，业务层通过 `ref.read(xxxProvider)` 访问。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/aes_gcm_crypto.dart';
import '../crypto/machine_fingerprint.dart';
import '../crypto/rsa_crypto.dart';
import '../network/dio_client.dart';
import '../platform/desktop_platform_service.dart';
import '../platform/mobile_platform_service.dart';
import '../platform/platform_service.dart';
import '../platform/system_integration_service.dart';
import '../storage/config_store.dart';
import '../storage/file_store.dart';
import '../storage/secure_storage.dart';

// ──────────────────────────── 网络 ────────────────────────────

/// Portal 认证专用 dio 实例
final portalDioProvider = Provider<Dio>((ref) => DioFactory.createPortalDio());

/// 公网请求 dio 实例
final publicDioProvider = Provider<Dio>((ref) => DioFactory.createPublicDio());

// ──────────────────────────── 加密 ────────────────────────────

/// RSA 公钥（从 State.py 提取，1024 位 PKCS#1）
const rsaPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyhncn4Z4RY8wITqV7n6hAapEM
ZwNBP6fflsGs3Ke5g6Ji4AWvNflIXZLNTGIuykoU1v2Bitylyuc9nSKLTvBdcytB
+4X4CvV4oVDr2aLrXs7LhTNyykcxyhyGhokph0Cb4yR/mybK6OeH2ME1/AZS7AZ4
pe2gw9lcwXQVF8DJwwIDAQAB
-----END PUBLIC KEY-----''';

/// RSA 加密器 Provider
final rsaCryptoProvider = Provider<RsaCrypto>(
  (ref) => RsaCrypto.fromPem(rsaPublicKeyPem),
);

/// AES-GCM 加密器 Provider（异步，需要 MachineGuid 派生密钥）
final aesGcmCryptoProvider = FutureProvider<AesGcmCrypto>((ref) async {
  final key = await MachineFingerprint.deriveEncryptionKey();
  return AesGcmCrypto(key);
});

// ──────────────────────────── 平台 ────────────────────────────

/// 平台服务 Provider（根据运行平台自动选择实现）
final platformServiceProvider = Provider<PlatformService>((ref) {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return DesktopPlatformService();
  }
  return MobilePlatformService();
});

// ──────────────────────────── 系统集成 ────────────────────────────

/// 系统集成服务 Provider
///
/// 依赖 fileStore 与 platformService，供 app.dart 与 settings_page 共用。
final systemIntegrationServiceProvider = Provider<SystemIntegrationService>(
  (ref) => SystemIntegrationService(
    fileStore: ref.watch(fileStoreProvider),
    platformService: ref.watch(platformServiceProvider),
  ),
);

// ──────────────────────────── 存储 ────────────────────────────

/// 配置存储 Provider（异步，依赖 SharedPreferences 初始化）
final configStoreProvider = FutureProvider<ConfigStore>((ref) async {
  final sp = await SharedPreferences.getInstance();
  return ConfigStore(sp);
});

/// 密码安全存储 Provider
final secureAccountStoreProvider = Provider<SecureAccountStore>(
  (ref) => SecureAccountStore(),
);

/// 文件存储 Provider
final fileStoreProvider = Provider<FileStore>((ref) => FileStore());
