/// 文件存储服务
///
/// 管理应用运行时文件：
/// - log.txt：日志文件（支持轮转）
/// - downloads.log：下载记录
/// - InterKnot.lock：文件锁（防多开）
/// - logout.signal：登出信号文件
/// - easytier.toml：EasyTier 配置文件
/// - InterKnot.zip：更新包临时文件
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 文件存储服务
class FileStore {
  String? _appDir;

  /// 获取应用数据目录
  Future<String> get appDir async {
    if (_appDir != null) return _appDir!;
    final dir = await getApplicationSupportDirectory();
    _appDir = dir.path;
    // 确保目录存在
    await Directory(_appDir!).create(recursive: true);
    return _appDir!;
  }

  /// 获取日志文件路径
  Future<File> get logFile async {
    final dir = await appDir;
    return File('$dir/log.txt');
  }

  /// 获取下载日志文件路径
  Future<File> get downloadsLogFile async {
    final dir = await appDir;
    return File('$dir/downloads.log');
  }

  /// 获取文件锁路径
  Future<File> get lockFile async {
    final dir = await appDir;
    return File('$dir/InterKnot.lock');
  }

  /// 获取登出信号文件路径
  Future<File> get logoutSignalFile async {
    final dir = await appDir;
    return File('$dir/logout.signal');
  }

  /// 获取 EasyTier 配置文件路径
  Future<File> get easytierTomlFile async {
    final dir = await appDir;
    return File('$dir/easytier.toml');
  }

  /// 获取临时 zip 文件路径
  Future<File> get tempZipFile async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/InterKnot');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/InterKnot.zip');
  }

  // ──────────────────────────── 日志操作 ────────────────────────────

  /// 写入日志（追加模式）
  ///
  /// 不再启动清空日志，改用轮转机制
  Future<void> appendLog(String message) async {
    final file = await logFile;
    await file.writeAsString(
      '$message\n',
      mode: FileMode.append,
    );
  }

  /// 读取所有日志
  Future<String> readLog() async {
    final file = await logFile;
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  /// 日志轮转：当前日志超过 [maxSize] 字节时重命名为 .old
  Future<void> rotateLogIfNeeded({int maxSize = 1024 * 1024}) async {
    final file = await logFile;
    if (!await file.exists()) return;
    final size = await file.length();
    if (size > maxSize) {
      final oldFile = File('${file.path}.old');
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      await file.rename(oldFile.path);
    }
  }

  // ──────────────────────────── 文件锁 ────────────────────────────

  /// 尝试获取文件锁（防多开）
  ///
  /// 返回 true 表示获取成功，false 表示已有实例运行
  Future<bool> tryLock() async {
    final file = await lockFile;
    if (await file.exists()) {
      // 检查锁是否过期（PID 是否还活着）
      try {
        final content = await file.readAsString();
        final pid = int.tryParse(content.trim());
        if (pid != null && _isProcessRunning(pid)) {
          return false; // 已有实例运行
        }
      } catch (_) {
        // 无法读取锁文件，视为无效
      }
      // 锁已过期，删除旧锁
      await file.delete();
    }
    // 写入当前 PID
    await file.writeAsString('$pid');
    return true;
  }

  /// 释放文件锁
  Future<void> unlock() async {
    final file = await lockFile;
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ──────────────────────────── 信号文件 ────────────────────────────

  /// 写入登出信号
  Future<void> writeLogoutSignal() async {
    final file = await logoutSignalFile;
    await file.writeAsString('');
  }

  /// 删除登出信号
  Future<void> clearLogoutSignal() async {
    final file = await logoutSignalFile;
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ──────────────────────────── EasyTier 配置 ────────────────────────────

  /// 写入 EasyTier TOML 配置
  Future<void> writeEasyTierToml(String tomlContent) async {
    final file = await easytierTomlFile;
    await file.writeAsString(tomlContent);
  }

  /// 读取 EasyTier TOML 配置
  Future<String?> readEasyTierToml() async {
    final file = await easytierTomlFile;
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  // ──────────────────────────── 内部方法 ────────────────────────────

  /// 检查进程是否运行（Windows）
  static bool _isProcessRunning(int pid) {
    try {
      final result = Process.runSync('tasklist', ['/FI', 'PID eq $pid']);
      return result.stdout.toString().contains('$pid');
    } catch (_) {
      return false;
    }
  }
}
