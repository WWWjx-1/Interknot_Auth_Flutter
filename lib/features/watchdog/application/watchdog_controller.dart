/// 看门狗控制器（Riverpod Notifier）
///
/// M4 任务：网络监测与自动重连。
///
/// 对应原 Python Watch_dog.py：
/// - 3 秒轮询 NLM 状态（connectivity_plus）
/// - 6 源公网连通性探测
/// - 退避重连（15 → 600s）
///
/// 退避策略：
/// - 初始冷却 15s
/// - 每次重连失败 +30s，上限 600s
/// - 重连成功后重置为 15s
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

// ──────────────────────────── 状态数据 ────────────────────────────

/// 看门狗连接状态
enum WatchdogConnectionStatus {
  /// 空闲/未启动
  idle,

  /// 正在检测
  checking,

  /// 已连接
  connected,

  /// 已断开
  disconnected,
}

/// 看门狗状态数据
class WatchdogState {
  /// 看门狗是否正在运行
  final bool isRunning;

  /// 是否正在执行检测
  final bool isChecking;

  /// 上次检测时间
  final DateTime? lastCheckTime;

  /// 当前冷却倒计时（秒）
  final int cooldownSeconds;

  /// 连接状态
  final WatchdogConnectionStatus connectionStatus;

  /// 状态描述消息
  final String statusMessage;

  /// 连续失败次数
  final int consecutiveFailures;

  const WatchdogState({
    this.isRunning = false,
    this.isChecking = false,
    this.lastCheckTime,
    this.cooldownSeconds = 0,
    this.connectionStatus = WatchdogConnectionStatus.idle,
    this.statusMessage = '',
    this.consecutiveFailures = 0,
  });

  static const idle = WatchdogState();

  WatchdogState copyWith({
    bool? isRunning,
    bool? isChecking,
    DateTime? lastCheckTime,
    int? cooldownSeconds,
    WatchdogConnectionStatus? connectionStatus,
    String? statusMessage,
    int? consecutiveFailures,
  }) {
    return WatchdogState(
      isRunning: isRunning ?? this.isRunning,
      isChecking: isChecking ?? this.isChecking,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}

// ──────────────────────────── Provider ────────────────────────────

/// 看门狗控制器 Provider
final watchdogControllerProvider =
    NotifierProvider<WatchdogController, WatchdogState>(
  WatchdogController.new,
);

// ──────────────────────────── 控制器 ────────────────────────────

/// 看门狗控制器
///
/// 职责：
/// - 周期性检测网络连通性（3s 间隔）
/// - 检测到断网后自动重连
/// - 退避冷却机制防止频繁重连
class WatchdogController extends Notifier<WatchdogState> {
  Logger get _logger => Logger('Watchdog');

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownValue = 0;

  // 轮询间隔（秒）
  static const _pollInterval = Duration(seconds: 3);

  // 退避参数
  static const _initialCooldown = 15;
  static const _maxCooldown = 600;
  static const _cooldownStep = 30;

  @override
  WatchdogState build() => WatchdogState.idle;

  // ──────────────────────────── 启动/停止 ────────────────────────────

  /// 启动看门狗
  ///
  /// 启动 3 秒轮询检测网络状态。
  /// 如果看门狗已在运行，则忽略。
  void start() {
    if (state.isRunning) {
      _logger.warn('看门狗已在运行中，忽略重复启动');
      return;
    }

    _logger.info('看门狗启动');
    _resetCooldown();
    state = state.copyWith(
      isRunning: true,
      connectionStatus: WatchdogConnectionStatus.checking,
      statusMessage: '看门狗运行中',
      consecutiveFailures: 0,
    );

    _pollTimer = Timer.periodic(_pollInterval, (_) => _tick());

    ref.onDispose(() {
      _pollTimer?.cancel();
      _cooldownTimer?.cancel();
      _logger.info('看门狗已释放资源');
    });
  }

  /// 停止看门狗
  void stop() {
    if (!state.isRunning) return;

    _logger.info('看门狗停止');
    _pollTimer?.cancel();
    _pollTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;

    state = state.copyWith(
      isRunning: false,
      isChecking: false,
      connectionStatus: WatchdogConnectionStatus.idle,
      statusMessage: '看门狗已停止',
      cooldownSeconds: 0,
    );
  }

  // ──────────────────────────── 检测逻辑 ────────────────────────────

  /// 每次轮询触发
  Future<void> _tick() async {
    // 检查配置：看门狗是否仍然启用
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config != null && !config.enableWatchdog) {
      _logger.debug('看门狗已被配置禁用，停止轮询');
      stop();
      return;
    }

    // 冷却中，跳过检测
    if (_cooldownValue > 0) {
      _logger.debug('冷却中（剩余 ${_cooldownValue}s），跳过检测');
      return;
    }

    state = state.copyWith(
      isChecking: true,
      lastCheckTime: DateTime.now(),
      statusMessage: '检测网络中...',
    );

    try {
      // 1. 检查本地网络连接（NLM）
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      final hasLocalNetwork = !result.contains(ConnectivityResult.none);
      if (!hasLocalNetwork) {
        _logger.debug('本地网络未连接');
        state = state.copyWith(
          isChecking: false,
          connectionStatus: WatchdogConnectionStatus.disconnected,
          statusMessage: '本地网络未连接',
        );
        return;
      }

      // 2. 检查公网连通性（使用增强的 fullStatus 检测）
      final dio = ref.read(publicDioProvider);
      final status = await ConnectivityChecker.checkFullStatus(dio: dio);

      switch (status) {
        case ConnectivityStatus.connected:
          // 网络正常
          _resetCooldown();
          state = state.copyWith(
            isChecking: false,
            connectionStatus: WatchdogConnectionStatus.connected,
            statusMessage: '网络已连接',
            cooldownSeconds: 0,
            consecutiveFailures: 0,
          );

        case ConnectivityStatus.portalDetected:
          // Portal 劫持（需要重新认证）
          _logger.warn('检测到 Portal 认证页面，准备重连');
          state = state.copyWith(
            isChecking: false,
            connectionStatus: WatchdogConnectionStatus.disconnected,
            statusMessage: '检测到认证页面',
          );
          _triggerReconnect();

        case ConnectivityStatus.disconnected:
          // 公网不通，触发重连
          _logger.warn('公网不可达，准备重连');
          state = state.copyWith(
            isChecking: false,
            connectionStatus: WatchdogConnectionStatus.disconnected,
            statusMessage: '公网不可达',
          );
          _triggerReconnect();
      }
    } catch (e, s) {
      _logger.error('看门狗检测异常', e, s);
      state = state.copyWith(
        isChecking: false,
        statusMessage: '检测异常: $e',
      );
    }
  }

  // ──────────────────────────── 重连与退避 ────────────────────────────

  /// 触发重连（带退避）
  void _triggerReconnect() {
    if (_cooldownValue > 0) {
      _logger.debug('已在冷却中（${_cooldownValue}s），跳过重连');
      return;
    }

    // 设置冷却值（初始 15s，之后每次失败 +30）
    if (state.consecutiveFailures == 0) {
      _cooldownValue = _initialCooldown;
    } else {
      _cooldownValue =
          (_cooldownValue + _cooldownStep).clamp(_initialCooldown, _maxCooldown);
    }

    _logger.info('进入冷却 ${_cooldownValue}s，然后尝试重连');
    state = state.copyWith(
      cooldownSeconds: _cooldownValue,
      statusMessage: '冷却中 ${_cooldownValue}s 后重连',
      consecutiveFailures: state.consecutiveFailures + 1,
    );

    // 启动冷却倒计时
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _cooldownValue--;
      state = state.copyWith(
        cooldownSeconds: _cooldownValue,
        statusMessage:
            _cooldownValue > 0 ? '冷却中 ${_cooldownValue}s 后重连' : '准备重连...',
      );

      if (_cooldownValue <= 0) {
        timer.cancel();
        _cooldownTimer = null;
        _executeReconnect();
      }
    });
  }

  /// 执行实际重连
  Future<void> _executeReconnect() async {
    _logger.info('开始执行重连');
    state = state.copyWith(
      statusMessage: '正在重连...',
      connectionStatus: WatchdogConnectionStatus.checking,
    );

    try {
      final config = ref.read(configStoreProvider).valueOrNull;
      if (config == null) {
        _logger.warn('配置未就绪，无法重连');
        return;
      }

      final username = config.username;
      if (username == null || username.isEmpty) {
        _logger.warn('未找到保存的用户名，无法自动重连');
        state = state.copyWith(
          statusMessage: '无保存凭据，无法自动重连',
        );
        return;
      }

      // 获取密码
      final secureStore = ref.read(secureAccountStoreProvider);
      final password = await secureStore.read(username);
      if (password == null || password.isEmpty) {
        _logger.warn('未找到用户 $username 的密码，无法自动重连');
        state = state.copyWith(
          statusMessage: '无保存密码，无法自动重连',
        );
        return;
      }

      // 调用认证控制器登录
      final authCtrl = ref.read(authControllerProvider.notifier);
      await authCtrl.login(
        user: username,
        password: password,
        loginMode: config.loginMode,
      );

      // 检查登录结果
      final authState = ref.read(authControllerProvider);
      if (authState.status == AuthStatus.connected) {
        // 重连成功
        _logger.info('重连成功');
        _resetCooldown();
        state = state.copyWith(
          connectionStatus: WatchdogConnectionStatus.connected,
          statusMessage: '重连成功',
          cooldownSeconds: 0,
          consecutiveFailures: 0,
        );
      } else {
        // 重连失败
        _logger.warn('重连失败: ${authState.statusMessage}');
        state = state.copyWith(
          connectionStatus: WatchdogConnectionStatus.disconnected,
          statusMessage: '重连失败: ${authState.statusMessage}',
        );
      }
    } catch (e, s) {
      _logger.error('重连异常', e, s);
      state = state.copyWith(
        connectionStatus: WatchdogConnectionStatus.disconnected,
        statusMessage: '重连异常: $e',
      );
    }
  }

  /// 重置冷却值
  void _resetCooldown() {
    _cooldownValue = 0;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }
}
