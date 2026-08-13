/// 应用日志服务
///
/// 对应原 Python `write_to_log`：
/// - 分级：DEBUG / INFO / WARN / ERROR
/// - 写入文件日志（不再启动清空，改为轮转）
/// - 可选控制台输出（DEBUG 模式）
///
/// 日志文件路径由 FileStore 管理，此模块只负责格式化与写入。
library;

import 'dart:async';
import 'dart:io';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get prefix {
    switch (this) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO ]';
      case LogLevel.warn:
        return '[WARN ]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }
}

/// 日志记录器
///
/// 用法：
/// ```dart
/// final logger = Logger('AuthController');
/// logger.info('登录成功');
/// logger.error('登录失败', error);
/// ```
class Logger {
  final String _tag;

  /// [tag] 标识日志来源模块
  Logger(this._tag);

  /// 日志文件写入回调（由外部注入，解耦 FileStore）
  static Future<void> Function(String formatted)? onLog;

  /// 日志条目回调（由外部注入，用于 LogBuffer / LogConsole）
  ///
  /// 参数：(tag, level, message, timestamp)
  static void Function(String tag, LogLevel level, String message, DateTime timestamp)? onEntry;

  /// 时间戳格式化
  static String get _timestamp {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4)}-'
        '${now.month.toString().padLeft(2)}-'
        '${now.day.toString().padLeft(2)} '
        '${now.hour.toString().padLeft(2)}:'
        '${now.minute.toString().padLeft(2)}:'
        '${now.second.toString().padLeft(2)}';
  }

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warn(String message) => _log(LogLevel.warn, message);
  void error(String message, [Object? error, StackTrace? stack]) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' | $error');
    }
    if (stack != null) {
      buffer.write('\n$stack');
    }
    _log(LogLevel.error, buffer.toString());
  }

  void _log(LogLevel level, String message) {
    final formatted = '$_timestamp ${level.prefix} [$_tag] $message';

    // 控制台输出
    // ignore: avoid_print
    print(formatted);

    // 写入文件
    onLog?.call(formatted);

    // 推送到 UI 日志缓冲区（供 LogConsole 显示）
    onEntry?.call(_tag, level, message, DateTime.now());
  }
}

/// 日志轮转管理器
class LogRotator {
  final String _logPath;
  final int _maxSize;

  LogRotator(this._logPath, {int maxSize = 1024 * 1024}) : _maxSize = maxSize;

  /// 写入一行日志，必要时自动轮转
  Future<void> writeLine(String line) async {
    await _rotateIfNeeded();
    final file = File(_logPath);
    await file.writeAsString('$line\n', mode: FileMode.append);
  }

  Future<void> _rotateIfNeeded() async {
    final file = File(_logPath);
    if (!await file.exists()) return;
    final size = await file.length();
    if (size > _maxSize) {
      final oldFile = File('$_logPath.old');
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      await file.rename(oldFile.path);
    }
  }
}
