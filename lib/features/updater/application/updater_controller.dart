/// 更新检查控制器（Riverpod Notifier）
///
/// M4 任务：从 cmxz.top 检查版本更新和远程停用。
///
/// 检查流程：
/// 1. GET https://cmxz.top/programs/sac/check.php（UA=CMXZ-SAC-Flutter_2.0.0）
/// 2. 解析响应中的版本号
/// 3. 与当前应用版本（package_info_plus）比较
/// 4. 检查 ?enable=0 远程停用标记
/// 5. 返回更新状态
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/core.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/esurfing_api.dart';

// ──────────────────────────── 状态枚举 ────────────────────────────

/// 更新检查状态
enum UpdaterStatus {
  /// 空闲
  idle,

  /// 正在检查
  checking,

  /// 有可用更新
  updateAvailable,

  /// 已是最新
  upToDate,

  /// 已远程停用
  disabled,

  /// 检查出错
  error,
}

// ──────────────────────────── 状态数据 ────────────────────────────

/// 更新检查状态数据
class UpdaterState {
  /// 当前检查状态
  final UpdaterStatus status;

  /// 最新版本号
  final String? latestVersion;

  /// 下载地址
  final String? downloadUrl;

  /// 是否强制更新
  final bool isForceUpdate;

  /// 状态消息
  final String statusMessage;

  /// 是否已被远程停用
  final bool isDisabled;

  const UpdaterState({
    this.status = UpdaterStatus.idle,
    this.latestVersion,
    this.downloadUrl,
    this.isForceUpdate = false,
    this.statusMessage = '',
    this.isDisabled = false,
  });

  static const initial = UpdaterState();

  UpdaterState copyWith({
    UpdaterStatus? status,
    String? latestVersion,
    String? downloadUrl,
    bool? isForceUpdate,
    String? statusMessage,
    bool? isDisabled,
  }) {
    return UpdaterState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isForceUpdate: isForceUpdate ?? this.isForceUpdate,
      statusMessage: statusMessage ?? this.statusMessage,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }
}

// ──────────────────────────── Provider ────────────────────────────

/// 更新检查控制器 Provider
final updaterControllerProvider =
    NotifierProvider<UpdaterController, UpdaterState>(
  UpdaterController.new,
);

// ──────────────────────────── 控制器 ────────────────────────────

/// 更新检查控制器
///
/// 负责：
/// - 调用 cmxz.top 检查版本
/// - 比较版本号
/// - 处理远程停用
class UpdaterController extends Notifier<UpdaterState> {
  Logger get _logger => Logger('Updater');

  @override
  UpdaterState build() => UpdaterState.initial;

  // ──────────────────────────── 版本检查 ────────────────────────────

  /// 检查更新
  ///
  /// 返回更新状态：
  /// - [UpdaterStatus.updateAvailable]：有可用更新
  /// - [UpdaterStatus.upToDate]：已是最新
  /// - [UpdaterStatus.disabled]：远程停用（已强制登出）
  /// - [UpdaterStatus.error]：检查失败
  Future<void> checkUpdate() async {
    state = state.copyWith(
      status: UpdaterStatus.checking,
      statusMessage: '正在检查更新...',
    );

    try {
      // 1. 发起更新检查请求
      final dio = ref.read(publicDioProvider);
      _logger.info('检查更新: ${EsurfingApi.updateCheckUrl}');

      final response = await dio.get<String>(
        EsurfingApi.updateCheckUrl,
        options: Options(
          headers: {'User-Agent': EsurfingApi.updateCheckUserAgent},
          responseType: ResponseType.plain,
        ),
      );

      final body = (response.data ?? '').trim();
      _logger.info('更新检查响应: $body');

      // 2. 检查远程停用
      if (_isDisabledResponse(body)) {
        _logger.warn('检测到远程停用标记，强制登出');
        await _forceLogout();
        state = state.copyWith(
          status: UpdaterStatus.disabled,
          statusMessage: '应用已被远程停用，请检查更新',
          isDisabled: true,
        );
        return;
      }

      // 3. 解析版本信息
      final versionInfo = _parseVersionResponse(body);
      if (versionInfo == null) {
        _logger.warn('无法解析版本信息，视为已是最新');
        state = state.copyWith(
          status: UpdaterStatus.upToDate,
          statusMessage: '已是最新版本',
        );
        return;
      }

      final remoteVersion = versionInfo.version;
      final downloadUrl = versionInfo.downloadUrl;
      final isForce = versionInfo.isForce;

      // 4. 获取当前应用版本
      final currentVersion = await _getCurrentVersion();
      _logger.info('版本比较: 当前=$currentVersion, 远程=$remoteVersion');

      // 5. 比较版本号
      if (VersionUtils.compare(remoteVersion, currentVersion) > 0) {
        // 有更新
        _logger.info('发现新版本: $remoteVersion (强制=$isForce)');
        state = state.copyWith(
          status: UpdaterStatus.updateAvailable,
          latestVersion: remoteVersion,
          downloadUrl: downloadUrl,
          isForceUpdate: isForce,
          statusMessage: '发现新版本 $remoteVersion',
        );
      } else {
        // 已是最新
        _logger.info('已是最新版本');
        state = state.copyWith(
          status: UpdaterStatus.upToDate,
          statusMessage: '已是最新版本',
        );
      }
    } on DioException catch (e, s) {
      _logger.error('更新检查网络异常', e, s);
      state = state.copyWith(
        status: UpdaterStatus.error,
        statusMessage: '网络异常: ${e.message}',
      );
    } catch (e, s) {
      _logger.error('更新检查异常', e, s);
      state = state.copyWith(
        status: UpdaterStatus.error,
        statusMessage: '检查失败: $e',
      );
    }
  }

  // ──────────────────────────── 内部方法 ────────────────────────────

  /// 获取当前应用版本号
  Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      _logger.warn('获取应用版本失败: $e，使用默认版本 1.0.0');
      return '1.0.0';
    }
  }

  /// 检查响应是否为远程停用标记
  ///
  /// 格式：response 中包含 "enable=0"
  bool _isDisabledResponse(String body) {
    return body.contains('enable=0');
  }

  /// 解析版本检查响应
  ///
  /// 支持的响应格式（示例）：
  /// - version=1.68&url=https://...&force=1
  /// - 1.68|https://...|1
  /// - 纯版本号字符串
  _VersionInfo? _parseVersionResponse(String body) {
    if (body.isEmpty) return null;

    // 格式 1: key=value&key=value（URL query 风格）
    if (body.contains('=') && body.contains('&')) {
      final params = Uri.splitQueryString(body);
      final version = params['version'];
      if (version != null && version.isNotEmpty) {
        return _VersionInfo(
          version: version,
          downloadUrl: params['url'] ?? params['downloadUrl'],
          isForce: params['force'] == '1' || params['isForce'] == '1',
        );
      }
    }

    // 格式 2: version|url|force（管道分隔）
    if (body.contains('|')) {
      final parts = body.split('|');
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        return _VersionInfo(
          version: parts[0].trim(),
          downloadUrl: parts.length > 1 ? parts[1].trim() : null,
          isForce: parts.length > 2 && parts[2].trim() == '1',
        );
      }
    }

    // 格式 3: 纯版本号
    if (_looksLikeVersion(body)) {
      return _VersionInfo(version: body);
    }

    return null;
  }

  /// 判断字符串是否像版本号（如 "1.2.3"）
  bool _looksLikeVersion(String s) {
    return RegExp(r'^\d+\.\d+(\.\d+)?').hasMatch(s.trim());
  }

  /// 远程停用：强制登出
  Future<void> _forceLogout() async {
    try {
      // 如果当前已登录，则执行登出
      final appState = ref.read(appStateProvider);
      if (appState.connected) {
        _logger.info('远程停用：执行强制登出');
        await ref.read(authControllerProvider.notifier).logout();
      }
      // 重置应用状态
      ref.read(appStateProvider.notifier).reset();
      _logger.info('远程停用：应用状态已重置');
    } catch (e, s) {
      _logger.error('强制登出失败', e, s);
    }
  }

  // ──────────────────────────── 状态重置 ────────────────────────────

  /// 重置为初始状态
  void reset() {
    state = UpdaterState.initial;
  }
}

// ──────────────────────────── 内部类型 ────────────────────────────

/// 解析后的版本信息
class _VersionInfo {
  final String version;
  final String? downloadUrl;
  final bool isForce;

  const _VersionInfo({
    required this.version,
    this.downloadUrl,
    this.isForce = false,
  });
}
