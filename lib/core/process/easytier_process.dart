/// EasyTier 子进程管理器
///
/// 对应原 Python `Easytier.py`：
/// - 启动 easytier-core 子进程（server/client 模式）
/// - 动态生成 toml 配置文件
/// - stdout 关键字状态机
/// - 路由增删（route add/delete 0.0.0.0 → 10.129.114.10）
///
/// 遵循 Flutter 陷阱清单：
/// - Timer/StreamSubscription 在 dispose 释放
/// - 平台通道调用 try/catch
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../platform/platform_service.dart';
import '../utils/logger.dart';

/// EasyTier 进程状态
enum EasyTierStatus {
  /// 未启动
  idle,
  /// 启动中
  starting,
  /// 运行中
  running,
  /// 已停止
  stopped,
  /// 错误
  error,
}

/// EasyTier 运行模式
enum EasyTierMode {
  /// 服务端（共享模式）
  server,
  /// 客户端（隧道模式）
  client,
}

/// EasyTier 进程条目
class EasyTierProcessEntry {
  final Process process;
  final int pid;
  final EasyTierMode mode;
  EasyTierStatus status;
  final DateTime startTime;

  EasyTierProcessEntry({
    required this.process,
    required this.pid,
    required this.mode,
    this.status = EasyTierStatus.starting,
    required this.startTime,
  });
}

/// EasyTier 启动结果
sealed class EasyTierStartResult {
  const EasyTierStartResult();
}

/// 启动成功
class EasyTierStartSuccess extends EasyTierStartResult {
  final int pid;
  const EasyTierStartSuccess(this.pid);
}

/// 启动失败
class EasyTierStartFailed extends EasyTierStartResult {
  final String reason;
  const EasyTierStartFailed(this.reason);
}

/// 已运行中
class EasyTierAlreadyRunning extends EasyTierStartResult {
  final int pid;
  const EasyTierAlreadyRunning(this.pid);
}

/// EasyTier 子进程管理器
///
/// 负责：
/// 1. 动态生成 easytier.toml 配置（server/client）
/// 2. 启动 easytier-core 子进程
/// 3. 解析 stdout 关键字（starting easytier / remote: wg:// / peer connection removed...）
/// 4. 路由增删（需管理员权限）
class EasyTierProcess {
  final PlatformService _platform;
  final Logger _logger = Logger('EasyTierProc');

  /// 当前运行的进程
  EasyTierProcessEntry? _entry;

  /// 是否正在运行
  bool get isRunning =>
      _entry != null && _entry!.status == EasyTierStatus.running;

  /// 当前模式
  EasyTierMode? get mode => _entry?.mode;

  /// 当前进程 PID
  int? get pid => _entry?.pid;

  /// stdout 行回调（UI 日志）
  void Function(String line)? onStdoutLine;

  /// 状态变更回调
  void Function(EasyTierStatus status)? onStatusChanged;

  /// 对端连接回调（remote: wg://...）
  void Function(String peerInfo)? onPeerConnected;

  /// 对端断开回调
  void Function(String peerInfo)? onPeerDisconnected;

  /// 配置
  final EasyTierConfig _config = EasyTierConfig();

  EasyTierProcess({required PlatformService platform}) : _platform = platform;

  // ──────────────────────────── 配置读写 ────────────────────────────

  /// 设置共享密钥
  void setSecretKey(String key) => _config.secretKey = key;

  /// 设置是否启用 IPv6
  void setEnableIpv6(bool v) => _config.enableIpv6 = v;

  /// 设置是否启用 Web 下载页
  void setEnableWebDownload(bool v) => _config.enableWebDownload = v;

  /// 设置限速（Mbps）
  void setSpeedLimit(int? mbps) => _config.speedLimit = mbps;

  /// 设置自定义 toml 路径
  void setUserConfigPath(String? path) => _config.userConfigPath = path;

  // ──────────────────────────── 启动服务端（共享） ────────────────────────────

  /// 启动 EasyTier 服务端（共享模式）
  ///
  /// 对应原 Python `Easytier.check_config_exist` server 分支
  Future<EasyTierStartResult> startServer() async {
    if (isRunning) {
      _logger.warn('EasyTier 已在运行中，PID=${_entry!.pid}');
      return EasyTierAlreadyRunning(_entry!.pid);
    }

    _logger.info('启动 EasyTier 服务端（共享模式）...');
    onStdoutLine?.call('正在启动 EasyTier 共享服务...');

    // 1. 解析 easytier-core 路径
    final corePath = await _resolveEasyTierPath();
    if (corePath == null) {
      const msg = '未找到 easytier-core 可执行文件';
      _logger.error(msg);
      return const EasyTierStartFailed(msg);
    }

    // 2. 生成 toml 配置
    final tomlContent = _buildServerToml();
    final tomlPath = await _writeTomlFile(tomlContent);
    _logger.info('TOML 配置已写入: $tomlPath');

    // 3. 启动子进程
    return _startProcess(corePath, tomlPath, EasyTierMode.server);
  }

  // ──────────────────────────── 启动客户端（隧道） ────────────────────────────

  /// 启动 EasyTier 客户端（隧道模式）
  ///
  /// 对应原 Python `Easytier.check_config_exist` client 分支
  ///
  /// [peerIp] 对端 IP（服务器地址）
  /// [secret] 共享密钥（可选，默认 Hello_InterKnot）
  Future<EasyTierStartResult> startClient({
    required String peerIp,
    String? secret,
  }) async {
    if (isRunning) {
      _logger.warn('EasyTier 已在运行中，PID=${_entry!.pid}');
      return EasyTierAlreadyRunning(_entry!.pid);
    }

    _logger.info('启动 EasyTier 客户端（隧道模式）→ $peerIp');
    onStdoutLine?.call('正在连接 EasyTier 隧道: $peerIp...');

    // 1. 解析 easytier-core 路径
    final corePath = await _resolveEasyTierPath();
    if (corePath == null) {
      const msg = '未找到 easytier-core 可执行文件';
      _logger.error(msg);
      return const EasyTierStartFailed(msg);
    }

    // 2. 生成 toml 配置
    final tomlContent = _buildClientToml(peerIp, secret ?? _config.secretKey);
    final tomlPath = await _writeTomlFile(tomlContent);
    _logger.info('TOML 配置已写入: $tomlPath');

    // 3. 添加路由
    try {
      await _platform.addRoute('0.0.0.0', '10.129.114.10');
      _logger.info('路由已添加: 0.0.0.0 → 10.129.114.10');
      onStdoutLine?.call('隧道路由已设置');
    } catch (e) {
      _logger.warn('添加路由失败（可能需要管理员权限）: $e');
      onStdoutLine?.call('警告：路由设置失败，隧道可能无法正常工作');
    }

    // 4. 启动子进程
    return _startProcess(corePath, tomlPath, EasyTierMode.client);
  }

  // ──────────────────────────── 进程管理 ────────────────────────────

  /// 启动子进程
  Future<EasyTierStartResult> _startProcess(
    String corePath,
    String configPath,
    EasyTierMode mode,
  ) async {
    try {
      final process = await Process.start(
        corePath,
        ['-c', configPath],
        mode: ProcessStartMode.normal,
      );

      final pid = process.pid;
      _entry = EasyTierProcessEntry(
        process: process,
        pid: pid,
        mode: mode,
        startTime: DateTime.now(),
      );

      _logger.info('EasyTier 进程 $pid 启动成功 (${mode.name})');
      onStdoutLine?.call('EasyTier 进程 $pid 已启动');

      // 监听进程退出
      unawaited(process.exitCode.then((code) {
        _logger.info('EasyTier 进程 $pid 退出，exitCode=$code');
        _entry?.status = EasyTierStatus.stopped;
        onStatusChanged?.call(EasyTierStatus.stopped);
        onStdoutLine?.call('EasyTier 进程已退出 (code=$code)');

        // 清理路由
        _cleanupRoute();
      }));

      // 启动 stdout 监控
      _monitorOutput(process, pid);

      // 短暂等待确认启动
      await Future.delayed(const Duration(milliseconds: 500));

      _entry!.status = EasyTierStatus.running;
      onStatusChanged?.call(EasyTierStatus.running);

      return EasyTierStartSuccess(pid);
    } catch (e, s) {
      _logger.error('启动 EasyTier 进程失败', e, s);
      return EasyTierStartFailed('启动 EasyTier 失败: $e');
    }
  }

  /// 监控 stdout 输出
  void _monitorOutput(Process process, int pid) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;

        _logger.info('et $pid: $trimmed');
        onStdoutLine?.call('et: $trimmed');

        // 关键字：启动完成
        if (trimmed.contains('starting easytier') ||
            trimmed.contains('Easytier started')) {
          _entry?.status = EasyTierStatus.running;
          onStatusChanged?.call(EasyTierStatus.running);
        }

        // 关键字：对端连接
        if (trimmed.contains('remote:') ||
            trimmed.contains('peer connection') && trimmed.contains('established')) {
          onPeerConnected?.call(trimmed);
          onStdoutLine?.call('对端已连接: $trimmed');
        }

        // 关键字：对端断开
        if (trimmed.contains('peer connection') && trimmed.contains('removed')) {
          onPeerDisconnected?.call(trimmed);
          onStdoutLine?.call('对端已断开: $trimmed');
        }
      },
      onError: (e) {
        _logger.error('et $pid stdout 读取异常: $e');
      },
    );

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        _logger.warn('et $pid stderr: $line');
        onStdoutLine?.call('et: [ERR] $line');
      },
    );
  }

  // ──────────────────────────── 停止 ────────────────────────────

  /// 停止 EasyTier 进程
  Future<void> stop() async {
    if (_entry == null) return;

    final pid = _entry!.pid;
    _logger.info('停止 EasyTier 进程 $pid...');
    onStdoutLine?.call('正在停止 EasyTier...');

    try {
      _entry!.process.kill(ProcessSignal.sigterm);
      _logger.info('EasyTier 进程 $pid 已发送 SIGTERM');
    } catch (e) {
      _logger.warn('SIGTERM 失败，尝试 SIGKILL: $e');
      try {
        _entry!.process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }

    _entry = null;

    // 清理路由
    await _cleanupRoute();

    onStatusChanged?.call(EasyTierStatus.stopped);
    onStdoutLine?.call('EasyTier 已停止');
  }

  /// 清理路由
  Future<void> _cleanupRoute() async {
    try {
      await _platform.deleteRoute('0.0.0.0');
      _logger.info('路由已清理');
    } catch (e) {
      _logger.warn('清理路由失败: $e');
    }
  }

  // ──────────────────────────── TOML 生成 ────────────────────────────

  /// 生成服务端 toml 配置
  ///
  /// 对应原 Python `Easytier.check_config_exist` server 分支
  String _buildServerToml() {
    final buf = StringBuffer();

    // 如果有自定义配置，使用自定义配置
    if (_config.userConfigPath != null) {
      try {
        return File(_config.userConfigPath!).readAsStringSync();
      } catch (e) {
        _logger.warn('读取自定义 toml 失败: $e，使用默认配置');
      }
    }

    buf.writeln('# EasyTier Server Config - Generated by InterKnot Auth 2.0');
    buf.writeln();
    buf.writeln('[instance]');
    buf.writeln('instance_name = "InterKnot_Server"');
    buf.writeln();
    buf.writeln('[network_identity]');
    buf.writeln('network_name = "InterKnot"');
    buf.writeln('network_secret = "${_config.secretKey}"');
    buf.writeln();
    buf.writeln('[listeners]');
    buf.writeln('tcp = ["0.0.0.0:${EasyTierConstants.defaultPort}"]');
    if (_config.enableIpv6) {
      buf.writeln('tcp = ["[::]:${EasyTierConstants.defaultPort}"]');
    }
    buf.writeln();
    buf.writeln('[rpc_portal]');
    buf.writeln('enabled = true');
    buf.writeln('listen = "127.0.0.1:${EasyTierConstants.rpcPort}"');
    buf.writeln();
    buf.writeln('[flags]');
    buf.writeln('default_protocol = "tcp"');
    if (_config.speedLimit != null && _config.speedLimit! > 0) {
      buf.writeln('speed_limit = ${_config.speedLimit}');
    }
    buf.writeln();
    if (_config.enableWebDownload) {
      buf.writeln('[http_download]');
      buf.writeln('enabled = true');
      buf.writeln('listen = "0.0.0.0:${EasyTierConstants.webuiPort}"');
      buf.writeln();
    }
    buf.writeln('[dhcp]');
    buf.writeln('ipv4 = "10.129.114.0/24"');

    return buf.toString();
  }

  /// 生成客户端 toml 配置
  ///
  /// 对应原 Python `Easytier.check_config_exist` client 分支
  String _buildClientToml(String peerIp, String secret) {
    final buf = StringBuffer();

    buf.writeln('# EasyTier Client Config - Generated by InterKnot Auth 2.0');
    buf.writeln();
    buf.writeln('[instance]');
    buf.writeln('instance_name = "InterKnot_Client"');
    buf.writeln();
    buf.writeln('[network_identity]');
    buf.writeln('network_name = "InterKnot"');
    buf.writeln('network_secret = "$secret"');
    buf.writeln();
    buf.writeln('[peers]');
    buf.writeln('[[peers]]');
    buf.writeln('uri = "tcp://$peerIp:${EasyTierConstants.defaultPort}"');
    buf.writeln();
    buf.writeln('[rpc_portal]');
    buf.writeln('enabled = true');
    buf.writeln('listen = "127.0.0.1:${EasyTierConstants.rpcPort}"');
    buf.writeln();
    buf.writeln('[flags]');
    buf.writeln('default_protocol = "tcp"');

    return buf.toString();
  }

  /// 写入 toml 文件
  Future<String> _writeTomlFile(String content) async {
    final appDir = await _platform.getAppDataDir();
    final tomlPath = '$appDir/easytier.toml';
    await File(tomlPath).writeAsString(content);
    return tomlPath;
  }

  // ──────────────────────────── 路径解析 ────────────────────────────

  /// 解析 easytier-core 可执行文件路径
  Future<String?> _resolveEasyTierPath() async {
    final exeName = Platform.isWindows ? 'easytier-core.exe' : 'easytier-core';

    // 1. 捆绑资源路径
    final bundledPath =
        await _platform.resolveAssetPath('assets/bin/easytier/$exeName');
    if (await File(bundledPath).exists()) {
      _logger.info('使用捆绑 easytier-core: $bundledPath');
      return bundledPath;
    }

    // 2. 系统 PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [exeName],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        if (await File(path).exists()) {
          _logger.info('使用系统 easytier-core: $path');
          return path;
        }
      }
    } catch (_) {}

    _logger.error('未找到 easytier-core');
    return null;
  }

  // ──────────────────────────── 资源释放 ────────────────────────────

  /// 释放所有资源
  void dispose() {
    onStdoutLine = null;
    onStatusChanged = null;
    onPeerConnected = null;
    onPeerDisconnected = null;
    unawaited(stop());
  }
}

/// EasyTier 配置
class EasyTierConfig {
  String secretKey;
  bool enableIpv6;
  bool enableWebDownload;
  int? speedLimit; // Mbps
  String? userConfigPath;

  EasyTierConfig({
    this.secretKey = EasyTierConstants.defaultSecret,
    this.enableIpv6 = false,
    this.enableWebDownload = false,
    this.speedLimit,
    this.userConfigPath,
  });
}

/// EasyTier 常量（对应原 Python 中的常量）
class EasyTierConstants {
  const EasyTierConstants._();

  /// 默认共享密钥
  static const defaultSecret = 'Hello_InterKnot';

  /// 默认虚拟 IP 段
  static const virtualIp = '10.129.114.10';

  /// 默认端口
  static const defaultPort = 51145;

  /// RPC 端口
  static const rpcPort = 15888;

  /// WebUI 端口（原 :50000）
  static const webuiPort = 50000;

  /// RPC 地址
  static const rpcAddress = '127.0.0.1';
}
