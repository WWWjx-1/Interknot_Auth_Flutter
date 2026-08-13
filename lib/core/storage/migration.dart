/// 数据迁移工具
///
/// 从旧 Python 项目（v1.68）迁移配置和密码到 Flutter 新格式：
///
/// 1. config.ini（`[key]=value` 格式）→ shared_preferences
/// 2. Secret.dat（AES-GCM 加密的账号密码）→ flutter_secure_storage
/// 3. Cred.c（Credential Manager，若存在）→ flutter_secure_storage
///
/// 迁移完成后设置 `migrated=true` 标记，避免重复迁移。
///
/// 对应施工文档 §4.5 配置文件格式兼容策略。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../crypto/aes_gcm_crypto.dart';
import '../crypto/machine_fingerprint.dart';
import 'config_store.dart';
import 'secure_storage.dart';

/// 数据迁移管理器
class DataMigrator {
  final ConfigStore _config;
  final SecureAccountStore _secureStorage;

  DataMigrator(this._config, this._secureStorage);

  /// 执行完整迁移流程
  ///
  /// 若 [migrated] 标记已为 true，跳过迁移。
  /// 返回迁移结果摘要。
  Future<MigrationResult> migrate() async {
    if (_config.migrated) {
      return MigrationResult(skipped: true, message: '已迁移，跳过');
    }

    final result = MigrationResult();

    try {
      // 1. 迁移 config.ini
      final configPath = await _findOldConfigPath();
      if (configPath != null) {
        final configResult = await _migrateConfig(configPath);
        result.configImported = configResult;
      }

      // 2. 迁移 Secret.dat
      final secretPath = await _findOldSecretPath();
      if (secretPath != null) {
        final secretResult = await _migrateSecrets(secretPath);
        result.accountsImported = secretResult;
      }

      // 3. 尝试迁移 Cred.c（若存在）
      final credResult = await _migrateCred();
      result.credAccountsImported = credResult;

      // 标记迁移完成
      _config.migrated = true;
      result.success = true;
      result.message = '迁移完成：'
          '配置 ${result.configImported} 项，'
          'Secret.dat 账号 ${result.accountsImported} 个，'
          'Cred 账号 ${result.credAccountsImported} 个';
    } catch (e, s) {
      result.success = false;
      result.message = '迁移失败: $e';
      debugPrint('迁移失败: $e\n$s');
    }

    return result;
  }

  // ──────────────────────────── 旧文件路径查找 ────────────────────────────

  /// 查找旧 config.ini 路径（%APPDATA%/SAC/config.ini）
  Future<String?> _findOldConfigPath() async {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'];
    if (appData == null) return null;

    final path = '$appData${Platform.pathSeparator}SAC${Platform.pathSeparator}config.ini';
    if (await File(path).exists()) return path;
    return null;
  }

  /// 查找旧 Secret.dat 路径（%APPDATA%/SAC/Secret.dat）
  Future<String?> _findOldSecretPath() async {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'];
    if (appData == null) return null;

    final path = '$appData${Platform.pathSeparator}SAC${Platform.pathSeparator}Secret.dat';
    if (await File(path).exists()) return path;
    return null;
  }

  // ──────────────────────────── config.ini 迁移 ────────────────────────────

  /// 将旧 `[key]=value` 格式配置迁移到 shared_preferences
  Future<int> _migrateConfig(String path) async {
    final content = await File(path).readAsString();
    final lines = content.split('\n');
    var count = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 解析 [key]=value 格式
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) continue;

      var key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();

      // 去掉键两边的方括号
      if (key.startsWith('[') && key.endsWith(']')) {
        key = key.substring(1, key.length - 1);
      }

      // 处理布尔值
      if (value == 'True' || value == 'true') {
        await _config.setRaw(key, true);
        count++;
        continue;
      }
      if (value == 'False' || value == 'false') {
        await _config.setRaw(key, false);
        count++;
        continue;
      }

      // 处理整数
      final intVal = int.tryParse(value);
      if (intVal != null) {
        await _config.setRaw(key, intVal);
        count++;
        continue;
      }

      // 默认字符串
      await _config.setRaw(key, value);
      count++;
    }

    return count;
  }

  // ──────────────────────────── Secret.dat 迁移 ────────────────────────────

  /// 解密旧 Secret.dat 并将账号密码导入 flutter_secure_storage
  Future<int> _migrateSecrets(String path) async {
    final content = await File(path).readAsString();
    final lines = content.split('\n');

    // 派生 AES 密钥（与原 Python 一致）
    final key = await MachineFingerprint.deriveEncryptionKey();
    final aesCrypto = AesGcmCrypto(key);

    var count = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 格式：[username]=base64_encrypted_password
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) continue;

      var username = trimmed.substring(0, eqIndex).trim();
      final encrypted = trimmed.substring(eqIndex + 1).trim();

      // 去掉用户名两边的方括号
      if (username.startsWith('[') && username.endsWith(']')) {
        username = username.substring(1, username.length - 1);
      }

      try {
        final password = aesCrypto.decrypt(encrypted);
        await _secureStorage.save(username, password);
        count++;
      } catch (e) {
        debugPrint('解密账号 $username 失败: $e');
        // 继续处理下一个账号
      }
    }

    return count;
  }

  // ──────────────────────────── Cred.c 迁移 ────────────────────────────

  /// 尝试从 Cred.c 编译产物读取凭据
  ///
  /// Cred.c 是旧项目的 Windows Credential Manager 工具，
  /// 若无编译产物则跳过此步骤。
  Future<int> _migrateCred() async {
    // Cred.c 迁移需要编译产物存在，当前跳过
    // 实际部署时可通过 platform channel 调用
    return 0;
  }
}

/// 迁移结果
class MigrationResult {
  bool success = false;
  bool skipped = false;
  String? message;
  int configImported = 0;
  int accountsImported = 0;
  int credAccountsImported = 0;

  MigrationResult({
    this.success = false,
    this.skipped = false,
    this.message,
  });
}
