/// 桌面端平台服务实现（Windows/macOS/Linux）
///
/// 提供完整的系统集成能力：
/// - jar 登录（Process.run + 捆绑 jre）
/// - EasyTier 组网
/// - 系统托盘、开机自启
/// - 路由管理、管理员权限检测
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

import 'platform_service.dart';

/// 桌面端平台服务实现
class DesktopPlatformService implements PlatformService {
  @override
  bool get supportsJarLogin => true;

  @override
  bool get supportsEasyTier => true;

  @override
  bool get supportsSystemTray => true;

  @override
  bool get supportsAutoStart => true;

  @override
  String get platformName => Platform.operatingSystem;

  @override
  Future<String> resolveAssetPath(String relativePath) async {
    // 桌面端：assets 文件被复制到数据目录，或直接使用可执行文件同目录
    // 对于捆绑的二进制文件，它们通常位于可执行文件同目录的 data/flutter_assets/assets/bin/
    final exeDir = Directory(Platform.resolvedExecutable).parent.path;
    final assetPath = '$exeDir/data/flutter_assets/$relativePath';
    if (await File(assetPath).exists()) {
      return assetPath;
    }
    // fallback：开发模式下在项目根目录
    final projectPath = '$exeDir/$relativePath';
    if (await File(projectPath).exists()) {
      return projectPath;
    }
    // 最后 fallback 到 assets/bin 直接路径
    return '$exeDir/$relativePath';
  }

  @override
  Future<String?> resolveJavaPath() async {
    // 优先使用捆绑的 jre
    final javaExe = Platform.isWindows ? 'java.exe' : 'java';
    final jrePath = await resolveAssetPath('assets/bin/jre/bin/$javaExe');
    if (await File(jrePath).exists()) {
      return jrePath;
    }

    // fallback：系统 PATH 中的 java
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['java'],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        if (await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<String> getAppDataDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  Future<String> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<void> addRoute(String destination, String gateway) async {
    if (Platform.isWindows) {
      await _runCommand('route', ['add', destination, 'mask', '0.0.0.0', gateway, 'metric', '1']);
    } else if (Platform.isLinux) {
      await _runCommand('ip', ['route', 'add', destination, 'via', gateway]);
    } else if (Platform.isMacOS) {
      await _runCommand('route', ['add', '-net', destination, gateway]);
    }
  }

  @override
  Future<void> deleteRoute(String destination) async {
    if (Platform.isWindows) {
      await _runCommand('route', ['delete', destination]);
    } else if (Platform.isLinux) {
      await _runCommand('ip', ['route', 'del', destination]);
    } else if (Platform.isMacOS) {
      await _runCommand('route', ['delete', '-net', destination]);
    }
  }

  @override
  Future<bool> hasAdminPrivilege() async {
    try {
      if (Platform.isWindows) {
        // 尝试写入 System32 目录检测管理员权限
        final result = await Process.run(
          'net',
          ['session'],
          runInShell: true,
        );
        return result.exitCode == 0;
      } else {
        // Unix: 检查 EUID
        final result = await Process.run('id', ['-u']);
        return (result.stdout as String).trim() == '0';
      }
    } catch (_) {
      return false;
    }
  }

  /// 执行命令行（内部使用 process_run）
  Future<ProcessResult> _runCommand(String cmd, List<String> args) async {
    final shell = Shell();
    try {
      await shell.run('$cmd ${args.join(' ')}');
      // 成功
      return ProcessResult(0, 0, '', '');
    } catch (e) {
      debugPrint('命令执行失败: $cmd ${args.join(' ')}: $e');
      rethrow;
    }
  }
}
