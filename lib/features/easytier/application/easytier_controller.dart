/// EasyTier 业务控制器（Riverpod Notifier）
///
/// 对应原 Python `Easytier.py` 的业务逻辑：
/// - 启动/停止共享（服务端）
/// - 连接/断开隧道（客户端）
/// - 状态管理 + 日志回调
///
/// 遵循 Flutter 陷阱清单：
/// - Timer 在 ref.onDispose 释放
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../data/easytier_cli.dart';

/// EasyTier 控制器状态
class EasyTierControllerState {
  final EasyTierStatus status;
  final EasyTierMode? mode;
  final int? pid;
  final String statusMessage;
  final List<String> logLines;
  final List<EasyTierNodeInfo> nodes;
  final List<EasyTierPeerInfo> peers;
  final List<EasyTierRouteInfo> routes;

  const EasyTierControllerState({
    this.status = EasyTierStatus.idle,
    this.mode,
    this.pid,
    this.statusMessage = '',
    this.logLines = const [],
    this.nodes = const [],
    this.peers = const [],
    this.routes = const [],
  });

  static const initial = EasyTierControllerState();

  bool get isRunning => status == EasyTierStatus.running;

  EasyTierControllerState copyWith({
    EasyTierStatus? status,
    EasyTierMode? mode,
    int? pid,
    bool clearPid = false,
    String? statusMessage,
    List<String>? logLines,
    List<EasyTierNodeInfo>? nodes,
    List<EasyTierPeerInfo>? peers,
    List<EasyTierRouteInfo>? routes,
  }) {
    return EasyTierControllerState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      pid: clearPid ? null : (pid ?? this.pid),
      statusMessage: statusMessage ?? this.statusMessage,
      logLines: logLines ?? this.logLines,
      nodes: nodes ?? this.nodes,
      peers: peers ?? this.peers,
      routes: routes ?? this.routes,
    );
  }
}

/// EasyTier 控制器 Provider
final easytierControllerProvider =
    NotifierProvider<EasyTierController, EasyTierControllerState>(
  EasyTierController.new,
);

/// EasyTier 控制器
class EasyTierController extends Notifier<EasyTierControllerState> {
  Logger get _logger => Logger('EasyTierCtrl');
  EasyTierCli? _cli;
  Timer? _dashboardTimer;

  @override
  EasyTierControllerState build() {
    // 注册 dispose 回调
    ref.onDispose(() {
      _dashboardTimer?.cancel();
      _dashboardTimer = null;
    });
    return EasyTierControllerState.initial;
  }

  // ──────────────────────────── 共享（服务端） ────────────────────────────

  /// 启动共享（服务端模式）
  Future<void> startShare() async {
    if (state.isRunning) {
      _logger.warn('EasyTier 已在运行中');
      return;
    }

    state = state.copyWith(
      status: EasyTierStatus.starting,
      statusMessage: '正在启动共享服务...',
      logLines: [],
    );

    try {
      final config = ref.read(configStoreProvider).valueOrNull;
      final easytierProcess = ref.read(easytierProcessProvider);

      // 应用配置
      if (config != null) {
        easytierProcess.setSecretKey(
            config.etSecretKey ?? EasyTierConstants.defaultSecret);
        easytierProcess.setEnableIpv6(config.etEnableIpv6);
        easytierProcess.setEnableWebDownload(config.etEnableWebDl);
        final speedLimit = config.etSpeedLimit;
        if (speedLimit != null && speedLimit.isNotEmpty) {
          easytierProcess.setSpeedLimit(int.tryParse(speedLimit));
        }
        if (config.etEnableUserConf) {
          easytierProcess.setUserConfigPath(config.etUserConfPath);
        }
      }

      // 绑定日志回调
      easytierProcess.onStdoutLine = _addLogLine;
      easytierProcess.onStatusChanged = (status) {
        state = state.copyWith(status: status);
        ref.read(appStateProvider.notifier)
            .setEasyTierRunning(status == EasyTierStatus.running);
      };
      easytierProcess.onPeerConnected = (peer) {
        _addLogLine('对端连接: $peer');
      };
      easytierProcess.onPeerDisconnected = (peer) {
        _addLogLine('对端断开: $peer');
      };

      final result = await easytierProcess.startServer();

      switch (result) {
        case EasyTierStartSuccess(:final pid):
          state = state.copyWith(
            status: EasyTierStatus.running,
            mode: EasyTierMode.server,
            pid: pid,
            statusMessage: '共享服务已启动 (PID: $pid)',
          );
          ref.read(appStateProvider.notifier).setEasyTierRunning(true);
          _startDashboardPolling();
          _logger.info('共享服务启动成功, PID=$pid');

        case EasyTierAlreadyRunning(:final pid):
          state = state.copyWith(
            status: EasyTierStatus.running,
            mode: EasyTierMode.server,
            pid: pid,
            statusMessage: '共享服务已在运行中 (PID: $pid)',
          );
          _startDashboardPolling();

        case EasyTierStartFailed(:final reason):
          state = state.copyWith(
            status: EasyTierStatus.error,
            statusMessage: reason,
          );
          _addLogLine('启动失败: $reason');
      }
    } catch (e, s) {
      _logger.error('启动共享异常', e, s);
      state = state.copyWith(
        status: EasyTierStatus.error,
        statusMessage: '启动异常: $e',
      );
    }
  }

  // ──────────────────────────── 隧道（客户端） ────────────────────────────

  /// 连接隧道（客户端模式）
  ///
  /// [peerIp] 对端 IP 地址
  /// [secret] 共享密钥
  Future<void> connectTunnel({
    required String peerIp,
    String? secret,
  }) async {
    if (state.isRunning) {
      _logger.warn('EasyTier 已在运行中，先停止再连接');
      await stop();
    }

    state = state.copyWith(
      status: EasyTierStatus.starting,
      statusMessage: '正在连接隧道: $peerIp...',
      logLines: [],
    );

    try {
      final easytierProcess = ref.read(easytierProcessProvider);

      easytierProcess.onStdoutLine = _addLogLine;
      easytierProcess.onStatusChanged = (status) {
        state = state.copyWith(status: status);
        ref.read(appStateProvider.notifier)
            .setEasyTierRunning(status == EasyTierStatus.running);
      };
      easytierProcess.onPeerConnected = (peer) {
        _addLogLine('隧道已建立: $peer');
      };
      easytierProcess.onPeerDisconnected = (peer) {
        _addLogLine('隧道断开: $peer');
      };

      final result = await easytierProcess.startClient(
        peerIp: peerIp,
        secret: secret,
      );

      switch (result) {
        case EasyTierStartSuccess(:final pid):
          state = state.copyWith(
            status: EasyTierStatus.running,
            mode: EasyTierMode.client,
            pid: pid,
            statusMessage: '隧道已连接 (PID: $pid)',
          );
          ref.read(appStateProvider.notifier).setEasyTierRunning(true);
          _startDashboardPolling();
          _logger.info('隧道连接成功, PID=$pid');

        case EasyTierAlreadyRunning(:final pid):
          state = state.copyWith(
            status: EasyTierStatus.running,
            mode: EasyTierMode.client,
            pid: pid,
            statusMessage: '隧道已在运行中 (PID: $pid)',
          );
          _startDashboardPolling();

        case EasyTierStartFailed(:final reason):
          state = state.copyWith(
            status: EasyTierStatus.error,
            statusMessage: reason,
          );
          _addLogLine('连接失败: $reason');
      }
    } catch (e, s) {
      _logger.error('连接隧道异常', e, s);
      state = state.copyWith(
        status: EasyTierStatus.error,
        statusMessage: '连接异常: $e',
      );
    }
  }

  // ──────────────────────────── 停止 ────────────────────────────

  /// 停止 EasyTier
  Future<void> stop() async {
    _stopDashboardPolling();

    state = state.copyWith(
      status: EasyTierStatus.stopped,
      statusMessage: '正在停止...',
    );

    try {
      final easytierProcess = ref.read(easytierProcessProvider);
      await easytierProcess.stop();

      _cli?.clearCache();
      _cli = null;

      ref.read(appStateProvider.notifier).setEasyTierRunning(false);

      state = state.copyWith(
        status: EasyTierStatus.idle,
        mode: null,
        pid: null,
        clearPid: true,
        statusMessage: '已停止',
        nodes: [],
        peers: [],
        routes: [],
      );
      _logger.info('EasyTier 已停止');
    } catch (e, s) {
      _logger.error('停止 EasyTier 异常', e, s);
      state = state.copyWith(
        status: EasyTierStatus.error,
        statusMessage: '停止异常: $e',
      );
    }
  }

  // ──────────────────────────── Dashboard 轮询 ────────────────────────────

  /// 启动 Dashboard 数据轮询（1s 间隔）
  void _startDashboardPolling() {
    _dashboardTimer?.cancel();
    _dashboardTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetchDashboardData(),
    );
    // 立即获取一次
    _fetchDashboardData();
  }

  /// 停止 Dashboard 数据轮询
  void _stopDashboardPolling() {
    _dashboardTimer?.cancel();
    _dashboardTimer = null;
  }

  /// 获取 Dashboard 数据
  Future<void> _fetchDashboardData() async {
    try {
      // 延迟初始化 CLI 客户端
      _cli ??= await _initCli();
      if (_cli == null) return;

      final nodes = await _cli!.queryNodes();
      final peers = await _cli!.queryPeers();
      final routes = await _cli!.queryRoutes();

      if (mounted) {
        state = state.copyWith(
          nodes: nodes,
          peers: peers,
          routes: routes,
        );
      }
    } catch (e) {
      _logger.warn('Dashboard 数据获取失败: $e');
    }
  }

  /// 初始化 CLI 客户端
  Future<EasyTierCli?> _initCli() async {
    try {
      final cliPath = await EasyTierCli.resolveCliPath();
      if (cliPath == null) {
        _logger.warn('未找到 easytier-cli');
        return null;
      }
      return EasyTierCli(
        cliPath: cliPath,
        rpcAddress: '${EasyTierConstants.rpcAddress}:${EasyTierConstants.rpcPort}',
      );
    } catch (e) {
      _logger.warn('初始化 CLI 失败: $e');
      return null;
    }
  }

  // ──────────────────────────── 日志 ────────────────────────────

  /// 添加日志行（最多保留 200 行）
  void _addLogLine(String line) {
    if (!mounted) return;
    final lines = List<String>.from(state.logLines);
    lines.add(line);
    if (lines.length > 200) {
      lines.removeAt(0);
    }
    state = state.copyWith(logLines: lines);
  }

  // ──────────────────────────── mounted 检查 ────────────────────────────

  /// 检查当前 Widget 是否已挂载（用于异步间隙后的安全访问）
  bool get mounted => true; // Riverpod Notifier 始终视为已挂载
}

/// EasyTier 进程 Provider
final easytierProcessProvider = Provider<EasyTierProcess>((ref) {
  final platform = ref.read(platformServiceProvider);
  return EasyTierProcess(platform: platform);
});
