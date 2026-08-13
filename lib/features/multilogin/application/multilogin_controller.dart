/// 多拨控制器（Riverpod Notifier）
///
/// 对应原 Python `Setting.py` 中的多拨登录管理：
/// - 多 tab 管理（每个 tab 一个 IP/账号/密码）
/// - IP 去重校验（重复 IP 拦截）
/// - 串行登录（50ms 间隔，避免并发冲突）
/// - 登录结果汇总
///
/// 密码加密存储：多拨密码通过 SecureAccountStore 加密存储，
/// 键格式为 `multilogin:{ip}:{account}`。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_dto.dart';

/// 多拨单个 tab 的配置数据
class MultiloginTabConfig {
  /// 唯一标识
  final int tabId;

  /// IP 地址
  final String ip;

  /// 账号
  final String account;

  /// 密码（明文，仅内存中使用）
  final String password;

  const MultiloginTabConfig({
    required this.tabId,
    required this.ip,
    required this.account,
    required this.password,
  });

  /// 用于 IP 去重的键
  String get ipKey => ip.trim();

  MultiloginTabConfig copyWith({
    int? tabId,
    String? ip,
    String? account,
    String? password,
  }) {
    return MultiloginTabConfig(
      tabId: tabId ?? this.tabId,
      ip: ip ?? this.ip,
      account: account ?? this.account,
      password: password ?? this.password,
    );
  }
}

/// 单个 tab 的登录结果
class MultiloginTabResult {
  final int tabId;
  final String ip;
  final String account;
  final bool success;
  final String message;

  const MultiloginTabResult({
    required this.tabId,
    required this.ip,
    required this.account,
    required this.success,
    required this.message,
  });
}

/// 多拨控制器状态
class MultiloginState {
  /// 所有 tab 配置
  final List<MultiloginTabConfig> tabs;

  /// 每个 tab 的登录结果
  final Map<int, MultiloginTabResult> results;

  /// 是否正在登录中
  final bool isLoggingIn;

  /// 当前正在登录的 tab 索引（-1 表示未开始）
  final int currentTabIndex;

  /// 状态消息
  final String statusMessage;

  /// 登录成功计数
  final int successCount;

  /// 登录失败计数
  final int failCount;

  const MultiloginState({
    this.tabs = const [],
    this.results = const {},
    this.isLoggingIn = false,
    this.currentTabIndex = -1,
    this.statusMessage = '',
    this.successCount = 0,
    this.failCount = 0,
  });

  static const initial = MultiloginState();

  MultiloginState copyWith({
    List<MultiloginTabConfig>? tabs,
    Map<int, MultiloginTabResult>? results,
    bool? isLoggingIn,
    int? currentTabIndex,
    String? statusMessage,
    int? successCount,
    int? failCount,
  }) {
    return MultiloginState(
      tabs: tabs ?? this.tabs,
      results: results ?? this.results,
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      statusMessage: statusMessage ?? this.statusMessage,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
    );
  }
}

/// 多拨控制器 Provider
final multiloginControllerProvider =
    NotifierProvider<MultiloginController, MultiloginState>(
  MultiloginController.new,
);

/// 多拨控制器
///
/// 管理多拨 tab 的增删改查和串行登录流程。
class MultiloginController extends Notifier<MultiloginState> {
  Logger get _logger => Logger('MultiLogin');

  /// 最大 tab 数量
  static const maxTabs = 10;

  /// 串行登录间隔（毫秒）
  static const loginIntervalMs = 50;

  @override
  MultiloginState build() {
    _loadTabsFromConfig();
    return MultiloginState.initial;
  }

  /// 从配置中加载已保存的多拨 tab
  Future<void> _loadTabsFromConfig() async {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null) return;

    final tabCount = config.multiloginTabCount;
    if (tabCount <= 0) return;

    final tabs = <MultiloginTabConfig>[];
    final secureStore = ref.read(secureAccountStoreProvider);

    for (var i = 0; i < tabCount; i++) {
      final ip = config.getMultiloginIp(i) ?? '';
      final account = config.getMultiloginAccount(i) ?? '';
      if (ip.isEmpty && account.isEmpty) continue;

      // 从安全存储读取密码
      final password = await secureStore.read(_makePasswordKey(ip, account)) ?? '';

      tabs.add(MultiloginTabConfig(
        tabId: i,
        ip: ip,
        account: account,
        password: password,
      ));
    }

    if (tabs.isNotEmpty) {
      state = state.copyWith(tabs: tabs);
    }
  }

  /// 添加新的多拨 tab
  Future<void> addTab({
    required String ip,
    required String account,
    required String password,
  }) async {
    if (state.tabs.length >= maxTabs) {
      _logger.warn('已达到最大 tab 数量限制($maxTabs)');
      throw MultiloginException('已达到最大 tab 数量限制($maxTabs)');
    }

    // IP 去重校验
    final trimmedIp = ip.trim();
    if (trimmedIp.isNotEmpty) {
      // 校验 IP 格式
      if (!IpUtils.isIPv4(trimmedIp)) {
        throw MultiloginException('无效的 IPv4 地址: $trimmedIp');
      }

      // 检查重复 IP
      final duplicate = state.tabs.any((t) => t.ipKey == trimmedIp);
      if (duplicate) {
        throw MultiloginException('IP 地址重复: $trimmedIp，多拨不能使用相同 IP');
      }
    }

    final newTabId = _nextTabId();
    final newTab = MultiloginTabConfig(
      tabId: newTabId,
      ip: trimmedIp,
      account: account.trim(),
      password: password,
    );

    // 保存密码到安全存储
    if (password.isNotEmpty) {
      await ref.read(secureAccountStoreProvider).save(
            _makePasswordKey(trimmedIp, account.trim()),
            password,
          );
    }

    // 保存配置
    await _saveTabsToConfig();

    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(tabs: newTabs);

    _logger.info('添加多拨 tab: ip=$trimmedIp, account=$account');
  }

  /// 更新 tab 配置
  Future<void> updateTab(
    int tabId, {
    String? ip,
    String? account,
    String? password,
  }) async {
    final index = state.tabs.indexWhere((t) => t.tabId == tabId);
    if (index == -1) return;

    final oldTab = state.tabs[index];
    final newIp = ip?.trim() ?? oldTab.ip;
    final newAccount = account?.trim() ?? oldTab.account;
    final newPassword = password ?? oldTab.password;

    // IP 去重（排除自身）
    if (ip != null) {
      final trimmedIp = ip.trim();
      if (!IpUtils.isIPv4(trimmedIp)) {
        throw MultiloginException('无效的 IPv4 地址: $trimmedIp');
      }
      final duplicate = state.tabs
          .where((t) => t.tabId != tabId)
          .any((t) => t.ipKey == trimmedIp);
      if (duplicate) {
        throw MultiloginException('IP 地址重复: $trimmedIp');
      }
    }

    // 更新安全存储中的密码
    if (password != null && password.isNotEmpty) {
      await ref.read(secureAccountStoreProvider).save(
            _makePasswordKey(newIp, newAccount),
            password,
          );
    }

    final updatedTabs = state.tabs.toList();
    updatedTabs[index] = oldTab.copyWith(
      ip: newIp,
      account: newAccount,
      password: newPassword,
    );

    state = state.copyWith(tabs: updatedTabs);
    await _saveTabsToConfig();

    _logger.info('更新多拨 tab $tabId: ip=$newIp, account=$newAccount');
  }

  /// 删除 tab
  Future<void> removeTab(int tabId) async {
    final tab = state.tabs.firstWhere(
      (t) => t.tabId == tabId,
      orElse: () => throw MultiloginException('Tab 不存在: $tabId'),
    );

    // 删除安全存储中的密码
    await ref.read(secureAccountStoreProvider).delete(
          _makePasswordKey(tab.ip, tab.account),
        );

    final updatedTabs = state.tabs.where((t) => t.tabId != tabId).toList();
    state = state.copyWith(tabs: updatedTabs);
    await _saveTabsToConfig();

    _logger.info('删除多拨 tab $tabId: ip=${tab.ip}');
  }

  /// 串行登录所有 tab
  ///
  /// 对应原 Python 的多拨串行登录逻辑：
  /// - 每个 tab 间隔 50ms 启动登录
  /// - 收集所有结果
  /// - 重复 IP 已在添加/更新时拦截
  Future<void> loginAll() async {
    if (state.isLoggingIn) {
      _logger.warn('多拨登录已在进行中');
      return;
    }

    if (state.tabs.isEmpty) {
      throw MultiloginException('没有配置多拨 tab');
    }

    final validTabs = state.tabs
        .where((t) => t.ip.isNotEmpty && t.account.isNotEmpty && t.password.isNotEmpty)
        .toList();

    if (validTabs.isEmpty) {
      throw MultiloginException('没有完整配置的多拨 tab（需要 IP、账号、密码）');
    }

    state = state.copyWith(
      isLoggingIn: true,
      currentTabIndex: 0,
      statusMessage: '开始多拨登录（共 ${validTabs.length} 个 tab）...',
      results: {},
      successCount: 0,
      failCount: 0,
    );

    _logger.info('开始多拨登录: ${validTabs.length} 个 tab');

    final results = <int, MultiloginTabResult>{};
    var successCount = 0;
    var failCount = 0;

    for (var i = 0; i < validTabs.length; i++) {
      final tab = validTabs[i];
      state = state.copyWith(
        currentTabIndex: i,
        statusMessage: '正在登录 tab ${i + 1}/${validTabs.length}: ${tab.ip}',
      );

      _logger.info('多拨登录 [$i/${validTabs.length}] ip=${tab.ip}, account=${tab.account}');

      try {
        final config = ref.read(configStoreProvider).valueOrNull;

        // 获取 Portal 参数（使用多拨 IP 作为 wlanuserip）
        final params = await ref
            .read(authRepositoryProvider)
            .fetchEsurfingParams();

        // 使用多拨的 IP 作为 wlanuserip
        final loginParams = params.copyWith(wlanUserIp: tab.ip);

        final result = await ref.read(authRepositoryProvider).login(
              user: tab.account,
              password: tab.password,
              esurfingUrl: loginParams.esurfingUrl,
              wlanAcIp: loginParams.wlanAcIp,
              wlanUserIp: loginParams.wlanUserIp,
              loginMode: config?.loginMode ?? 0,
            );

        if (result is LoginSuccess) {
          successCount++;
          results[tab.tabId] = MultiloginTabResult(
            tabId: tab.tabId,
            ip: tab.ip,
            account: tab.account,
            success: true,
            message: '登录成功',
          );
          _logger.info('多拨 tab ${tab.ip} 登录成功');
        } else if (result is LoginFailed) {
          failCount++;
          results[tab.tabId] = MultiloginTabResult(
            tabId: tab.tabId,
            ip: tab.ip,
            account: tab.account,
            success: false,
            message: result.message,
          );
          _logger.warn('多拨 tab ${tab.ip} 登录失败: ${result.message}');
        }
      } catch (e) {
        failCount++;
        results[tab.tabId] = MultiloginTabResult(
          tabId: tab.tabId,
          ip: tab.ip,
          account: tab.account,
          success: false,
          message: '登录异常: $e',
        );
        _logger.error('多拨 tab ${tab.ip} 登录异常', e);
      }

      // 更新状态
      state = state.copyWith(
        results: Map.from(results),
        successCount: successCount,
        failCount: failCount,
      );

      // 间隔 50ms 后启动下一个 tab（对应原 50ms 间隔）
      if (i < validTabs.length - 1) {
        await Future.delayed(const Duration(milliseconds: loginIntervalMs));
      }
    }

    state = state.copyWith(
      isLoggingIn: false,
      currentTabIndex: -1,
      statusMessage: '多拨登录完成: 成功 $successCount, 失败 $failCount',
    );

    _logger.info('多拨登录完成: 成功=$successCount, 失败=$failCount');
  }

  /// 登出所有 tab
  Future<void> logoutAll() async {
    _logger.info('开始多拨登出...');
    state = state.copyWith(
      statusMessage: '正在登出所有 tab...',
    );

    try {
      // 终止所有 jar 进程
      final platform = ref.read(platformServiceProvider);
      if (platform.supportsJarLogin) {
        await ref.read(jarProcessProvider).terminateAllImmediately();
      }

      // HTTP 路径登出
      for (final _ in state.tabs) {
        try {
          final params = await ref
              .read(authRepositoryProvider)
              .fetchEsurfingParams();
          await ref.read(authRepositoryProvider).logout(
                esurfingUrl: params.esurfingUrl,
                signature: '',
              );
        } catch (_) {
          // 忽略单个 tab 登出失败
        }
      }

      state = state.copyWith(
        results: {},
        successCount: 0,
        failCount: 0,
        statusMessage: '已登出所有 tab',
      );

      _logger.info('多拨登出完成');
    } catch (e) {
      _logger.error('多拨登出失败', e);
      state = state.copyWith(
        statusMessage: '登出失败: $e',
      );
    }
  }

  /// 获取下一个可用的 tab ID
  int _nextTabId() {
    if (state.tabs.isEmpty) return 0;
    return state.tabs.map((t) => t.tabId).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// 保存 tab 配置到 ConfigStore
  Future<void> _saveTabsToConfig() async {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null) return;

    // 先清除旧的多拨配置
    final oldCount = config.multiloginTabCount;
    for (var i = 0; i < oldCount; i++) {
      await config.setMultiloginIp(i, '');
      await config.setMultiloginAccount(i, '');
      await config.setMultiloginPassword(i, '');
    }

    // 写入新配置
    for (var i = 0; i < state.tabs.length; i++) {
      final tab = state.tabs[i];
      await config.setMultiloginIp(i, tab.ip);
      await config.setMultiloginAccount(i, tab.account);
      await config.setMultiloginPassword(i, tab.account); // 存账号名作为引用
    }

    config.multiloginTabCount = state.tabs.length;
  }

  /// 构造安全存储的密码键
  static String _makePasswordKey(String ip, String account) {
    return 'multilogin:$ip:$account';
  }
}

/// 多拨异常
class MultiloginException implements Exception {
  final String message;
  const MultiloginException(this.message);

  @override
  String toString() => 'MultiloginException: $message';
}
