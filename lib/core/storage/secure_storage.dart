/// 密码安全存储封装
///
/// 使用 flutter_secure_storage 替代原 Python AES-GCM 自实现加密方案。
///
/// - Windows：DPAPI 加密
/// - macOS：Keychain
/// - Android：EncryptedSharedPreferences (Keystore)
/// - iOS：Keychain
///
/// 存储键格式：`account:{username}`
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 账户密码安全存储
class SecureAccountStore {
  final FlutterSecureStorage _storage;

  SecureAccountStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  /// 保存密码
  ///
  /// [user] 账号，[password] 明文密码
  Future<void> save(String user, String password) async {
    await _storage.write(key: _makeKey(user), value: password);
  }

  /// 读取密码
  ///
  /// 返回明文密码，若无则返回 null
  Future<String?> read(String user) async {
    return _storage.read(key: _makeKey(user));
  }

  /// 删除密码
  Future<void> delete(String user) async {
    await _storage.delete(key: _makeKey(user));
  }

  /// 列出所有已保存的账号
  Future<List<String>> listAccounts() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith(kPrefix))
        .map((k) => k.substring(kPrefix.length))
        .toList();
  }

  /// 判断是否有已保存的账号
  Future<bool> hasAccounts() async {
    final accounts = await listAccounts();
    return accounts.isNotEmpty;
  }

  /// 保存任意键值对
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// 读取任意键值对
  Future<String?> readKey(String key) async {
    return _storage.read(key: key);
  }

  /// 删除所有数据
  @visibleForTesting
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  static const kPrefix = 'account:';
  static String _makeKey(String user) => '$kPrefix$user';
}
