/// 全局应用状态
///
/// 对应原 Python `State.py` 中的 `global_state` 单例。
/// 使用 Riverpod Notifier 替代可变单例，实现不可变状态管理。
///
/// 状态字段对应原 state 对象的字段：
/// - connected：是否已认证
/// - signature：登录 signature cookie
/// - 以及所有配置派生字段
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用全局状态数据
class AppStateData {
  /// 是否已认证（校园网登录成功）
  final bool connected;

  /// 登录 signature cookie（HTTP 路径）
  final String signature;

  /// 当前用户名
  final String currentUser;

  /// 当前登录模式（0=jar, 1=HTTP）
  final int loginMode;

  /// 看门狗是否运行中
  final bool watchdogRunning;

  /// EasyTier 是否运行中
  final bool easytierRunning;

  /// 是否正在登录中
  final bool loggingIn;

  /// 最后一条状态消息（用于 UI 展示）
  final String statusMessage;

  const AppStateData({
    this.connected = false,
    this.signature = '',
    this.currentUser = '',
    this.loginMode = 0,
    this.watchdogRunning = false,
    this.easytierRunning = false,
    this.loggingIn = false,
    this.statusMessage = '',
  });

  static const initial = AppStateData();

  AppStateData copyWith({
    bool? connected,
    String? signature,
    String? currentUser,
    int? loginMode,
    bool? watchdogRunning,
    bool? easytierRunning,
    bool? loggingIn,
    String? statusMessage,
  }) {
    return AppStateData(
      connected: connected ?? this.connected,
      signature: signature ?? this.signature,
      currentUser: currentUser ?? this.currentUser,
      loginMode: loginMode ?? this.loginMode,
      watchdogRunning: watchdogRunning ?? this.watchdogRunning,
      easytierRunning: easytierRunning ?? this.easytierRunning,
      loggingIn: loggingIn ?? this.loggingIn,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// 全局状态 Provider
class AppState extends Notifier<AppStateData> {
  @override
  AppStateData build() => AppStateData.initial;

  /// 设置连接状态
  void setConnected(bool v) => state = state.copyWith(connected: v);

  /// 设置 signature
  void setSignature(String s) => state = state.copyWith(signature: s);

  /// 设置当前用户
  void setCurrentUser(String user) => state = state.copyWith(currentUser: user);

  /// 设置登录模式
  void setLoginMode(int mode) => state = state.copyWith(loginMode: mode);

  /// 设置看门狗运行状态
  void setWatchdogRunning(bool v) =>
      state = state.copyWith(watchdogRunning: v);

  /// 设置 EasyTier 运行状态
  void setEasyTierRunning(bool v) =>
      state = state.copyWith(easytierRunning: v);

  /// 设置登录中状态
  void setLoggingIn(bool v) => state = state.copyWith(loggingIn: v);

  /// 设置状态消息
  void setStatusMessage(String msg) =>
      state = state.copyWith(statusMessage: msg);

  /// 重置为初始状态
  void reset() => state = AppStateData.initial;
}

/// 全局状态 Provider
final appStateProvider = NotifierProvider<AppState, AppStateData>(AppState.new);
