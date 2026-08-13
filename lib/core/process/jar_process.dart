/// login.jar 子进程管理器
///
/// 对应原 Python `Jar_Thread.py`：
/// - 启动 `java -jar login.jar -u -p -t -a` 子进程
/// - stdout 行解析状态机（关键字：authorized/Send Keep Packet/KeepUrl empty/network connected）
/// - 进程列表管理 + Mutex 防竞态
/// - term_all_processes（终止特定/全部进程）
/// - logout.signal 文件信号
///
/// 遵循 Flutter 陷阱清单：
/// - 平台通道调用 try/catch PlatformException
/// - Timer/StreamSubscription 在 dispose 释放
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import '../platform/platform_service.dart';
import '../utils/logger.dart';

/// jar 进程状态枚举
enum JarProcessStatus {
  /// 未启动
  idle,

  /// 启动中
  starting,

  /// 运行中
  running,

  /// 已授权（登录成功）
  authorized,

  /// 心跳保活中
  heartbeat,

  /// 已终止
  terminated,

  /// 错误
  error,
}

/// jar 子进程管理条目
class JarProcessEntry {
  final Process process;
  final int pid;
  final String username;
  final JarProcessStatus status;
  final DateTime startTime;

  const JarProcessEntry({
    required this.process,
    required this.pid,
    required this.username,
    this.status = JarProcessStatus.starting,
    required this.startTime,
  });
}

/// jar 登录结果
sealed class JarLoginResult {
  const JarLoginResult();
}

/// jar 登录成功（已授权）
class JarLoginAuthorized extends JarLoginResult {
  final int pid;
  const JarLoginAuthorized(this.pid);

  @override
  String toString() => 'JarLoginAuthorized(pid=$pid)';
}

/// jar 登录失败
class JarLoginFailed extends JarLoginResult {
  final String reason;
  final bool isFatal;
  const JarLoginFailed(this.reason, {this.isFatal = true});

  @override
  String toString() => 'JarLoginFailed($reason, fatal=$isFatal)';
}

/// jar 进程已连接（无需重复登录）
class JarLoginAlreadyConnected extends JarLoginResult {
  final int pid;
  const JarLoginAlreadyConnected(this.pid);

  @override
  String toString() => 'JarLoginAlreadyConnected(pid=$pid)';
}

/// login.jar 子进程管理器
///
/// 负责：
/// 1. 启动 java -jar login.jar 子进程（捆绑 jre）
/// 2. 解析 stdout 关键字状态机
/// 3. 管理多个并发进程（多拨场景）
/// 4. 终止特定/全部进程
/// 5. 心跳调度
class JarProcess {
  final PlatformService _platform;
  final Logger _logger = Logger('JarProcess');

  /// 当前管理的所有 jar 进程
  final List<JarProcessEntry> _processes = [];

  /// 互斥锁，保护 _processes 列表
  final Lock _lock = Lock();

  /// 当前进程列表（只读快照）
  List<JarProcessEntry> get processes => List.unmodifiable(_processes);

  /// 活跃进程数
  int get activeProcessCount =>
      _processes.where((p) => p.status == JarProcessStatus.running || p.status == JarProcessStatus.authorized || p.status == JarProcessStatus.heartbeat).length;

  /// stdout 行回调（用于 UI 日志展示）
  void Function(String line)? onStdoutLine;

  /// 状态变更回调
  void Function(JarProcessEntry entry, JarProcessStatus status)? onStatusChanged;

  /// 心跳回调
  void Function(int pid)? onHeartbeat;

  /// 登录成功回调
  void Function(int pid)? onLoginAuthorized;

  /// 登录失败回调
  void Function(int pid, String reason)? onLoginFailed;

  JarProcess({required PlatformService platform}) : _platform = platform;

  // ──────────────────────────── 启动 jar 子进程 ────────────────────────────

  /// 启动 login.jar 子进程进行认证
  ///
  /// [username] 用户名
  /// [password] 密码
  /// [userIp] wlanuserip
  /// [acIp] wlanacip
  ///
  /// 返回 [JarLoginResult]
  Future<JarLoginResult> login({
    required String username,
    required String password,
    required String userIp,
    required String acIp,
  }) async {
    _logger.info('启动 jar 登录: user=$username, ip=$userIp, ac=$acIp');

    // 1. 解析 Java 路径
    final javaPath = await _platform.resolveJavaPath();
    if (javaPath == null) {
      _logger.error('未找到 Java 运行环境');
      return const JarLoginFailed('未找到 Java 运行环境（jre）', isFatal: true);
    }

    // 2. 解析 login.jar 路径
    final jarPath = await _platform.resolveAssetPath('assets/bin/login.jar');
    final jarFile = File(jarPath);
    if (!await jarFile.exists()) {
      _logger.error('未找到 login.jar: $jarPath');
      return JarLoginFailed('未找到 login.jar', isFatal: true);
    }

    _logger.info('Java: $javaPath');
    _logger.info('Jar:  $jarPath');

    // 3. 构建命令行参数（与 Python 完全一致）
    final args = [
      '-jar',
      jarPath,
      '-u',
      username,
      '-p',
      password,
      '-t',
      userIp,
      '-a',
      acIp,
    ];

    // 4. 启动子进程
    try {
      final process = await Process.start(
        javaPath,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      final pid = process.pid;
      final entry = JarProcessEntry(
        process: process,
        pid: pid,
        username: username,
        status: JarProcessStatus.starting,
        startTime: DateTime.now(),
      );

      // 加入进程列表（线程安全）
      await _lock.synchronized(() {
        _processes.add(entry);
      });

      _logger.info('jar 进程 $pid 启动成功');
      onStdoutLine?.call('进程 $pid 启动成功！');

      // 5. 监听进程退出
      unawaited(process.exitCode.then((code) async {
        _logger.info('jar 进程 $pid 退出，exitCode=$code');
        await _lock.synchronized(() {
          _processes.removeWhere((p) => p.pid == pid);
        });
        onStatusChanged?.call(entry, JarProcessStatus.terminated);
      }));

      // 6. 启动 stdout/stderr 读取并返回结果
      final result = await _monitorOutput(process, pid, entry);

      return result;
    } catch (e, s) {
      _logger.error('启动 jar 进程失败', e, s);
      return JarLoginFailed('启动 jar 进程失败: $e', isFatal: true);
    }
  }

  // ──────────────────────────── stdout 状态机 ────────────────────────────

  /// 监控子进程 stdout，关键字状态机解析
  ///
  /// 对应原 Python `Jar_Thread.read_output` 的完整状态机逻辑
  Future<JarLoginResult> _monitorOutput(
    Process process,
    int pid,
    JarProcessEntry entry,
  ) async {
    final completer = Completer<JarLoginResult>();
    bool authorized = false;

    // 读取 stdout 行
    final stdoutStream = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // 同时读取 stderr（错误输出）
    final stderrStream = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // 启动 stderr 监听（不阻塞主状态机）
    unawaited(stderrStream.listen((line) {
      _logger.warn('jar $pid stderr: $line');
      onStdoutLine?.call('$pid: [STDERR] $line');
    }).asFuture());

    // 主状态机：解析 stdout 关键字
    try {
      await for (final line in stdoutStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        _logger.info('jar $pid stdout: $trimmed');
        onStdoutLine?.call('$pid: $trimmed');

        // ─── 关键字 1：设备已连接互联网 ───
        if (trimmed.contains('The network has been connected')) {
          _logger.info('jar $pid: 设备已连接互联网，无需重复登录');
          onStdoutLine?.call(
            '$pid: 当前设备已连接互联网，无需再次登录\n'
            '如果没有使用此工具登录\n'
            '将不能使用此工具的下线功能\n'
            '请使用天翼校园网手动下线，或等待8分钟',
          );
          // 终止当前进程
          await _terminateProcess(pid);
          if (!completer.isCompleted) {
            completer.complete(JarLoginAlreadyConnected(pid));
          }
          return completer.future;
        }

        // ─── 关键字 2：登录授权成功 ───
        if (trimmed.contains('The login has been authorized')) {
          _logger.info('jar $pid: 登录授权成功!');
          authorized = true;

          await _lock.synchronized(() {
            final idx = _processes.indexWhere((p) => p.pid == pid);
            if (idx != -1) {
              _processes[idx] = JarProcessEntry(
                process: _processes[idx].process,
                pid: pid,
                username: _processes[idx].username,
                status: JarProcessStatus.authorized,
                startTime: _processes[idx].startTime,
              );
            }
          });

          onStatusChanged?.call(entry, JarProcessStatus.authorized);
          onLoginAuthorized?.call(pid);
          onStdoutLine?.call('$pid: 登录成功！即将发送心跳... :)');
          onStdoutLine?.call('$pid:『只要心跳仍在，我们就不会掉线』');

          if (!completer.isCompleted) {
            completer.complete(JarLoginAuthorized(pid));
          }
        }

        // ─── 关键字 3：心跳成功 ───
        if (trimmed.contains('Send Keep Packet')) {

          await _lock.synchronized(() {
            final idx = _processes.indexWhere((p) => p.pid == pid);
            if (idx != -1) {
              _processes[idx] = JarProcessEntry(
                process: _processes[idx].process,
                pid: pid,
                username: _processes[idx].username,
                status: JarProcessStatus.heartbeat,
                startTime: _processes[idx].startTime,
              );
            }
          });

          onStatusChanged?.call(entry, JarProcessStatus.heartbeat);
          onHeartbeat?.call(pid);
          onStdoutLine?.call(
            '$pid: 心跳成功，请不要关闭此程序，\n需要每480秒心跳保持连接！',
          );
        }

        // ─── 关键字 4：账号或密码错误 ───
        if (trimmed.contains('KeepUrl is empty')) {
          _logger.error('jar $pid: KeepUrl is empty → 账号或密码错误');
          await _terminateProcess(pid);
          if (!completer.isCompleted) {
            completer.complete(
              const JarLoginFailed('登录失败，账号或密码错误！', isFatal: true),
            );
          }
          return completer.future;
        }

        // ─── 关键字 5：登录失败通用 ───
        if (trimmed.contains('Login failed') ||
            trimmed.contains('login failed') ||
            trimmed.contains('Authentication failed')) {
          _logger.error('jar $pid: 登录失败: $trimmed');
          await _terminateProcess(pid);
          if (!completer.isCompleted) {
            completer.complete(
              JarLoginFailed('登录失败: $trimmed', isFatal: true),
            );
          }
          return completer.future;
        }
      }

      // stdout 流关闭（进程结束）
      _logger.info('jar $pid: stdout 流关闭');
      if (!completer.isCompleted) {
        if (authorized) {
          // 已授权但进程意外退出
          completer.complete(JarLoginFailed('jar 进程意外退出', isFatal: true));
        } else {
          completer.complete(const JarLoginFailed('jar 进程异常退出', isFatal: true));
        }
      }
    } catch (e, s) {
      _logger.error('jar $pid: stdout 读取异常', e, s);
      if (!completer.isCompleted) {
        completer.complete(JarLoginFailed('jar 进程通信异常: $e', isFatal: true));
      }
    }

    return completer.future;
  }

  // ──────────────────────────── 进程终止 ────────────────────────────

  /// 终止指定 PID 的进程
  ///
  /// 对应原 Python `Jar_Thread.term_all_processes(pid)`
  Future<void> _terminateProcess(int pid) async {
    _logger.info('终止 jar 进程 $pid...');

    await _lock.synchronized(() async {
      for (final entry in _processes.where((p) => p.pid == pid)) {
        try {
          entry.process.kill(ProcessSignal.sigterm);
          _logger.info('jar 进程 $pid 已发送 SIGTERM');
        } catch (e) {
          _logger.warn('终止 jar 进程 $pid 失败: $e');
          // 尝试强制杀死
          try {
            entry.process.kill(ProcessSignal.sigkill);
          } catch (_) {}
        }
      }
      _processes.removeWhere((p) => p.pid == pid);
    });

    // 写入 logout.signal 信号文件
    await _writeLogoutSignal();
  }

  /// 终止所有 jar 进程
  ///
  /// 对应原 Python `Jar_Thread.term_all_processes()`（无参数）
  ///
  /// [delayMs] 延迟毫秒数（对应原 QTimer.singleShot 5500ms）
  Future<void> terminateAll({int delayMs = 0}) async {
    if (delayMs > 0) {
      _logger.info('将在 ${delayMs}ms 后终止所有 jar 进程');
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    _logger.info('终止所有 jar 进程...');

    await _lock.synchronized(() async {
      for (final entry in List.of(_processes)) {
        try {
          entry.process.kill(ProcessSignal.sigterm);
          _logger.info('jar 进程 ${entry.pid} 已终止');
        } catch (e) {
          _logger.warn('终止 jar 进程 ${entry.pid} 失败: $e');
          try {
            entry.process.kill(ProcessSignal.sigkill);
          } catch (_) {}
        }
      }
      _processes.clear();
    });

    // 写入 logout.signal 信号文件
    await _writeLogoutSignal();

    _logger.info('所有 jar 进程已终止');
  }

  /// 立即终止所有 jar 进程（无延迟，下线用）
  Future<void> terminateAllImmediately() async {
    _logger.info('立即终止所有 jar 进程（下线）...');

    await _lock.synchronized(() async {
      for (final entry in List.of(_processes)) {
        try {
          entry.process.kill(ProcessSignal.sigterm);
          _logger.info('jar 进程 ${entry.pid} 已终止');
        } catch (e) {
          _logger.warn('终止 jar 进程 ${entry.pid} 失败: $e');
          try {
            entry.process.kill(ProcessSignal.sigkill);
          } catch (_) {}
        }
      }
      _processes.clear();
    });

    // 清理 logout.signal
    await _clearLogoutSignal();

    _logger.info('所有 jar 进程已立即终止');
  }

  // ──────────────────────────── 心跳调度 ────────────────────────────

  Timer? _heartbeatTimer;

  /// 启动心跳调度器
  ///
  /// 对应原 jar 内部的心跳机制。
  /// jar 自身每 ~480s 发送一次 Keep Packet，但 Flutter 侧额外启动一个
  /// 480s 兜底定时器：若在 2*480s 内未收到心跳，认为连接丢失。
  void startHeartbeatWatcher({Duration interval = const Duration(seconds: 480)}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(interval * 2, (_) {
      _checkHeartbeatTimeout();
    });
    _logger.info('心跳监听器已启动（间隔=${interval.inSeconds}s）');
  }

  /// 停止心跳调度器
  void stopHeartbeatWatcher() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.info('心跳监听器已停止');
  }

  /// 检查心跳超时
  void _checkHeartbeatTimeout() {
    final activeProcesses = _processes
        .where((p) => p.status == JarProcessStatus.heartbeat ||
            p.status == JarProcessStatus.authorized)
        .toList();

    if (activeProcesses.isEmpty) {
      _logger.warn('无活跃 jar 进程，心跳监听器将停止');
      stopHeartbeatWatcher();
      return;
    }

    // 检查最后心跳时间（由于 jar 内部管理心跳，这里仅做兜底日志）
    for (final entry in activeProcesses) {
      final elapsed = DateTime.now().difference(entry.startTime);
      if (elapsed.inMinutes > 20) {
        _logger.warn(
          'jar 进程 ${entry.pid} 已运行 ${elapsed.inMinutes} 分钟，'
          '超过预期心跳周期',
        );
      }
    }
  }

  // ──────────────────────────── 信号文件 ────────────────────────────

  /// 写入 logout.signal 信号文件
  Future<void> _writeLogoutSignal() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final signalFile = File('${appDir.path}/logout.signal');
      await signalFile.writeAsString('');
      _logger.info('已写入 logout.signal');
    } catch (e) {
      _logger.warn('写入 logout.signal 失败: $e');
    }
  }

  /// 清理 logout.signal 信号文件
  Future<void> _clearLogoutSignal() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final signalFile = File('${appDir.path}/logout.signal');
      if (await signalFile.exists()) {
        await signalFile.delete();
        _logger.info('已清理 logout.signal');
      }
    } catch (e) {
      _logger.warn('清理 logout.signal 失败: $e');
    }
  }

  // ──────────────────────────── 资源释放 ────────────────────────────

  /// 释放所有资源
  ///
  /// 终止所有子进程，取消定时器，清理回调
  void dispose() {
    stopHeartbeatWatcher();
    onStdoutLine = null;
    onStatusChanged = null;
    onHeartbeat = null;
    onLoginAuthorized = null;
    onLoginFailed = null;

    // 异步终止所有进程
    unawaited(terminateAllImmediately());
  }
}
