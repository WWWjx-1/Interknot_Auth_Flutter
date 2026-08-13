/// 认证控制器（Riverpod Notifier）
///
/// 对应原 Python：
/// - Login_Thread：登录流程编排
/// - login_Retry_Thread：验证码错误重试
/// - WorkerSignals 中的登录相关信号
///
/// 职责：
/// - 取参（fetchEsurfingParams）
/// - 登录（login）含自动重试
/// - 登出（logout）
/// - 状态管理
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../data/auth_dto.dart';
import '../data/auth_repository.dart';
import '../data/esurfing_api.dart';
import '../domain/auth_state.dart';

/// 认证控制器状态
class AuthControllerState {
  final AuthStatus status;
  final String? signature;
  final String? currentUser;
  final String statusMessage;
  final int retryCount;
  final EsurfingParams? params;

  const AuthControllerState({
    this.status = AuthStatus.idle,
    this.signature,
    this.currentUser,
    this.statusMessage = '',
    this.retryCount = 0,
    this.params,
  });

  static const initial = AuthControllerState();

  AuthControllerState copyWith({
    AuthStatus? status,
    String? signature,
    String? currentUser,
    String? statusMessage,
    int? retryCount,
    EsurfingParams? params,
    bool clearSignature = false,
    bool clearUser = false,
  }) {
    return AuthControllerState(
      status: status ?? this.status,
      signature: clearSignature ? null : (signature ?? this.signature),
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      statusMessage: statusMessage ?? this.statusMessage,
      retryCount: retryCount ?? this.retryCount,
      params: params ?? this.params,
    );
  }
}

/// 认证控制器 Provider
final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(
  AuthController.new,
);

/// 认证控制器
class AuthController extends Notifier<AuthControllerState> {
  Logger get _logger => Logger('AuthCtrl');

  @override
  AuthControllerState build() => AuthControllerState.initial;

  // ──────────────────────────── 取参 ────────────────────────────

  /// 获取 Portal 参数（esurfingurl, wlanacip, wlanuserip）
  Future<void> fetchParams() async {
    state = state.copyWith(
      status: AuthStatus.fetchingParams,
      statusMessage: '正在获取 Portal 参数...',
    );

    try {
      final repo = ref.read(authRepositoryProvider);
      final params = await repo.fetchEsurfingParams();

      state = state.copyWith(
        status: AuthStatus.idle,
        statusMessage: '参数获取成功',
        params: params,
      );

      _logger.info('参数获取成功: $params');
    } catch (e, s) {
      _logger.error('参数获取失败', e, s);
      state = state.copyWith(
        status: AuthStatus.error,
        statusMessage: '参数获取失败: $e',
      );
    }
  }

  // ──────────────────────────── 登录 ────────────────────────────

  /// 执行登录
  ///
  /// [user] 用户名
  /// [password] 密码
  /// [loginMode] 登录模式（0=jar, 1=HTTP）
  Future<void> login({
    required String user,
    required String password,
    required int loginMode,
  }) async {
    if (state.status == AuthStatus.loggingIn) {
      _logger.warn('已有登录进行中，忽略重复请求');
      return;
    }

    state = state.copyWith(
      status: AuthStatus.loggingIn,
      currentUser: user,
      statusMessage: '正在登录...',
      retryCount: 0,
    );

    try {
      final repo = ref.read(authRepositoryProvider);
      final config = ref.read(configStoreProvider).valueOrNull;

      // 获取 Portal 参数（若未获取）
      EsurfingParams params;
      if (state.params != null) {
        params = state.params!;
      } else {
        state = state.copyWith(statusMessage: '获取 Portal 参数...');
        params = await repo.fetchEsurfingParams();
        state = state.copyWith(params: params);
      }

      final result = await repo.login(
        user: user,
        password: password,
        esurfingUrl: params.esurfingUrl,
        wlanAcIp: params.wlanAcIp,
        wlanUserIp: params.wlanUserIp,
        loginMode: loginMode,
      );

      switch (result) {
        case LoginSuccess(:final signature, :final authorized):
          // 保存 signature 到全局状态（HTTP 路径）
          if (signature != null) {
            ref.read(appStateProvider.notifier).setSignature(signature);
          }
          ref.read(appStateProvider.notifier)
            ..setConnected(true)
            ..setCurrentUser(user);

          state = state.copyWith(
            status: AuthStatus.connected,
            signature: signature,
            currentUser: user,
            statusMessage: authorized ? 'jar 登录成功（心跳保活中）' : '登录成功',
          );

          // 保存密码（如果配置了记住密码）
          if (config?.savePassword ?? false) {
            await ref.read(secureAccountStoreProvider).save(user, password);
          }

          // 保存用户名
          if (config != null) {
            config.username = user;
          }

          _logger.info('登录成功: user=$user, authorized=$authorized');

        case LoginFailed(:final message, :final isCaptchaError):
          state = state.copyWith(
            status: AuthStatus.error,
            statusMessage: message,
            retryCount: isCaptchaError ? state.retryCount + 1 : state.retryCount,
          );
          _logger.error('登录失败: $message');

        case LoginInProgress(:final step):
          state = state.copyWith(statusMessage: step);
      }
    } catch (e, s) {
      _logger.error('登录异常', e, s);
      state = state.copyWith(
        status: AuthStatus.error,
        statusMessage: '登录异常: $e',
      );
    }
  }

  // ──────────────────────────── 登出 ────────────────────────────

  /// 执行登出
  ///
  /// HTTP 路径：POST /ajax/logout
  /// jar 路径：终止所有 jar 子进程 + 清理信号文件
  Future<void> logout() async {
    final signature = state.signature ?? ref.read(appStateProvider).signature;
    final params = state.params;

    state = state.copyWith(
      status: AuthStatus.loggingIn,
      statusMessage: '正在登出...',
    );

    try {
      final platform = ref.read(platformServiceProvider);

      // jar 路径：终止所有 jar 进程
      if (platform.supportsJarLogin) {
        final jarProcess = ref.read(jarProcessProvider);
        await jarProcess.terminateAllImmediately();
        _logger.info('jar 进程已终止（登出）');
      }

      // HTTP 路径：POST 登出
      if (params != null && signature.isNotEmpty) {
        final repo = ref.read(authRepositoryProvider);
        await repo.logout(
          esurfingUrl: params.esurfingUrl,
          signature: signature,
        );
      }

      // 重置状态
      ref.read(appStateProvider.notifier)
        ..setConnected(false)
        ..setSignature('');

      state = state.copyWith(
        status: AuthStatus.idle,
        signature: null,
        currentUser: null,
        statusMessage: '已登出',
        clearSignature: true,
        clearUser: true,
      );

      _logger.info('登出成功');
    } catch (e, s) {
      _logger.error('登出失败', e, s);
      state = state.copyWith(
        status: AuthStatus.error,
        statusMessage: '登出失败: $e',
      );
    }
  }

  // ──────────────────────────── 状态重置 ────────────────────────────

  /// 重置为初始状态
  void reset() {
    state = AuthControllerState.initial;
  }
}

/// 认证仓库 Provider
///
/// 根据平台自动注入正确的依赖（含 jar 进程管理器）
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final platform = ref.read(platformServiceProvider);

  return AuthRepositoryImpl(
    portalDio: ref.read(portalDioProvider),
    publicDio: ref.read(publicDioProvider),
    rsaCrypto: ref.read(rsaCryptoProvider),
    ocrService: ref.read(ocrServiceProvider),
    // 桌面端注入 JarProcess，移动端为 null
    jarProcess: platform.supportsJarLogin
        ? ref.read(jarProcessProvider)
        : null,
  );
});

/// jar 进程管理器 Provider（仅桌面端）
final jarProcessProvider = Provider<JarProcess>((ref) {
  final platform = ref.read(platformServiceProvider);
  return JarProcess(platform: platform);
});

/// OCR 服务 Provider（根据平台选择实现，M6 终态）
///
/// 桌面端：优先 TFLite → 回退 Python OCR
/// 移动端：MLKit OCR
final ocrServiceProvider = Provider<OcrService>((ref) {
  final platform = ref.read(platformServiceProvider);
  if (platform.supportsJarLogin) {
    // 桌面端：使用 OcrServiceFactory 自动选择最佳实现
    // TFLite 可用时优先使用，否则回退 Python OCR
    return OcrServiceFactory.createBestAvailable();
  }
  // 移动端：MLKit OCR
  return MlKitOcrService();
});
