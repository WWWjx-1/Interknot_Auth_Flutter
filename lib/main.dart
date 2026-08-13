/// 绳网认证 InterKnot_Auth v2.0.0 入口文件
///
/// M4 增强：系统托盘、文件锁防多开、开机自启、看门狗、更新检查
/// M7 增强：启动崩溃捕获 + l10n 国际化初始化
///
/// 启动流程：
/// 1. 初始化 Flutter 绑定
/// 2. 桌面端：初始化窗口管理器 + DPI
/// 3. 初始化日志文件写入
/// 4. 文件锁防多开检查（在 app.dart 中通过 ProviderScope 完成）
/// 5. 系统托盘初始化（在 app.dart 中完成）
/// 6. 开机自启（在 app.dart 中完成）
/// 7. 启动更新检查（在 app.dart 中完成）
/// 8. 启动看门狗（在 app.dart 中完成，若配置启用）
/// 9. ProviderScope + runApp
library;

import 'dart:io' show File, FileMode, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/utils/logger.dart';
import 'shared/widgets/log_console.dart';

final _logger = Logger('Main');

/// 启动崩溃日志文件路径
String? _crashLogPath;

void main() async {
  // M7: 全局异常捕获 — 在 runApp 之前设置
  await _initCrashCapture();

  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端：初始化窗口管理器
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await _initWindowManager();
  }

  // 初始化日志文件写入（将 Logger 输出写入 LogBuffer）
  _initLoggerBuffer();

  // 创建 ProviderScope 并启动应用
  runApp(const ProviderScope(child: InterKnotApp()));

  _logger.info('绳网认证 2.0 启动完成');
}

/// 初始化桌面窗口管理器
Future<void> _initWindowManager() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(340, 740),
    minimumSize: Size(240, 580),
    center: true,
    title: '绳网认证 2.0',
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 显式保证任务栏图标可见（修复某些情况下被 setSkipTaskbar(true) 后
    // 窗口最小化到托盘时任务栏和托盘都看不到的问题）
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  });
}

/// 初始化 LogBuffer（连接 Logger 输出到 UI 日志控制台）
///
/// 将 Logger 输出同时写入 LogBuffer 供 LogConsole Widget 显示。
void _initLoggerBuffer() {
  Logger.onLog = (formatted) async {
    try {
      final levelMatch = RegExp(
        r'\[(DEBUG|INFO\s|WARN\s|ERROR)\]',
      ).firstMatch(formatted);
      final tagMatch = RegExp(
        r'\[([^\]]+)\]',
      ).allMatches(formatted).skip(1).firstOrNull;

      final level = switch (levelMatch?.group(1)?.trim()) {
        'DEBUG' => LogLevel.debug,
        'INFO' => LogLevel.info,
        'WARN' => LogLevel.warn,
        'ERROR' => LogLevel.error,
        _ => LogLevel.info,
      };

      final tag = tagMatch?.group(1) ?? 'App';
      final messageStart = formatted.indexOf('] [$tag] ');
      final message = messageStart >= 0
          ? formatted.substring(messageStart + 3 + tag.length + 3)
          : formatted;

      LogBuffer.add(
        LogEntry(
          timestamp: DateTime.now(),
          level: level,
          tag: tag,
          message: message,
        ),
      );
    } catch (_) {
      LogBuffer.add(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          tag: 'App',
          message: formatted,
        ),
      );
    }
  };
}

// ──────────────────────────── M7: 启动崩溃捕获 ────────────────────────────

/// 初始化全局异常捕获
///
/// 对应原 Python 的启动崩溃写入文件逻辑。
/// 所有未捕获的同步/异步异常都将写入 startup_crash.log。
Future<void> _initCrashCapture() async {
  // 确定崩溃日志路径
  try {
    final tempDir =
        Platform.environment['TEMP'] ?? Platform.environment['TMP'] ?? '.';
    _crashLogPath =
        '$tempDir${Platform.pathSeparator}InterKnot_Auth_startup_crash.log';
  } catch (_) {
    _crashLogPath = 'startup_crash.log';
  }

  // 捕获 Flutter 框架异常
  FlutterError.onError = (FlutterErrorDetails details) {
    _writeCrashLog(
      'Flutter Error: ${details.exception}\n'
      'Stack: ${details.stack}\n'
      'Context: ${details.library}',
    );
    // 仍然输出到控制台
    FlutterError.presentError(details);
  };

  // 捕获未处理的异步异常（Zone 级别）
  PlatformDispatcher.instance.onError = (error, stack) {
    _writeCrashLog('Unhandled Exception: $error\nStack: $stack');
    return true; // 阻止应用崩溃退出，继续运行
  };

  // 捕获 Dart 侧的同步异常（通过 runZonedGuarded 的等价方式）
  // Flutter 3.x 已内置，由 PlatformDispatcher 处理
}

/// 写入崩溃日志到文件
void _writeCrashLog(String message) {
  if (_crashLogPath == null) return;
  try {
    final file = File(_crashLogPath!);
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp]\n$message\n---\n';
    if (file.existsSync()) {
      file.writeAsStringSync(entry, mode: FileMode.append);
    } else {
      file.writeAsStringSync(entry);
    }
  } catch (_) {
    // 无法写入崩溃日志时静默失败
  }
}
