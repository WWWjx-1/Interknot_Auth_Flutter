/// 设置页面
///
/// 对应原 Python `Setting.py` 设置窗口：
/// - 登录参数（esurfingurl/wlanacip/wlanuserip）
/// - 自动获取参数按钮
/// - 隧道配置（密钥/IPv6/下载页/限速/自定义 toml）
/// - 清除配置
/// - 打开配置目录
///
/// 遵循 Flutter 陷阱清单：
/// - 异步间隙后检查 mounted
/// - 静态 widget 用 const
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/esurfing_api.dart';
import 'params_page.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _esurfingUrlController = TextEditingController();
  final _wlanAcIpController = TextEditingController();
  final _wlanUserIpController = TextEditingController();

  final _etSecretKeyController = TextEditingController();
  final _etSpeedLimitController = TextEditingController();
  final _etUserConfPathController = TextEditingController();

  bool _etEnableIpv6 = false;
  bool _etEnableWebDl = false;
  bool _etEnableUserConf = false;
  bool _autoStartEnabled = false;   // 开机自启开关状态
  bool _autoStartSupported = true;  // 当前平台是否支持
  bool _minimizeToTray = true;      // 关闭时最小化至托盘
  bool _traySupported = true;       // 当前平台是否支持托盘
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _esurfingUrlController.dispose();
    _wlanAcIpController.dispose();
    _wlanUserIpController.dispose();
    _etSecretKeyController.dispose();
    _etSpeedLimitController.dispose();
    _etUserConfPathController.dispose();
    super.dispose();
  }

  void _loadConfig() async {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null || !mounted) return;

    _esurfingUrlController.text = config.esurfingUrl ?? '';
    _wlanAcIpController.text = config.wlanAcIp ?? '';
    _wlanUserIpController.text = config.wlanUserIp ?? '';

    _etSecretKeyController.text =
        config.etSecretKey ?? EsurfingApi.etDefaultSecret;
    _etSpeedLimitController.text = config.etSpeedLimit ?? '';

    // ── 新增：开机自启状态同步 ──
    final platform = ref.read(platformServiceProvider);
    final supported = platform.supportsAutoStart;
    // 系统真实状态可能被外部（任务管理器/系统设置）改变，以 isAutoStartEnabled() 为准
    bool realEnabled = false;
    if (supported) {
      final sys = ref.read(systemIntegrationServiceProvider);
      try {
        realEnabled = await sys.isAutoStartEnabled();
        // 若系统状态与配置不一致，以系统为准回写配置
        if (realEnabled != config.launchAtStartup) {
          config.launchAtStartup = realEnabled;
        }
      } catch (e) {
        // 兜底：launch_at_startup 包未 setup 时会抛 UnsupportedError，
        // 这里静默忽略，按配置显示，不影响用户操作
        realEnabled = config.launchAtStartup;
      }
    }

    if (!mounted) return;
    setState(() {
      _etEnableIpv6 = config.etEnableIpv6;
      _etEnableWebDl = config.etEnableWebDl;
      _etEnableUserConf = config.etEnableUserConf;
      _etUserConfPathController.text = config.etUserConfPath ?? '';
      _autoStartEnabled = realEnabled;
      _autoStartSupported = supported;
      _minimizeToTray = config.minimizeToTray;
      _traySupported = platform.supportsSystemTray;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.saveSettings,
            onPressed: _isLoading ? null : _saveConfig,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 登录参数 ──
          _buildSectionHeader(l10n.loginParams, Icons.tune),
          const SizedBox(height: 8),
          _buildParamField(
            label: l10n.portalAddress,
            hint: l10n.portalAddressHint,
            controller: _esurfingUrlController,
            icon: Icons.router,
          ),
          const SizedBox(height: 8),
          _buildParamField(
            label: l10n.acIp,
            hint: l10n.acIpHint,
            controller: _wlanAcIpController,
            icon: Icons.wifi,
          ),
          const SizedBox(height: 8),
          _buildParamField(
            label: l10n.userIp,
            hint: l10n.userIpHint,
            controller: _wlanUserIpController,
            icon: Icons.computer,
          ),
          const SizedBox(height: 12),
          // 自动获取参数按钮
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _fetchParams,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            label: Text(l10n.autoFetchParams),
          ),
          const SizedBox(height: 8),
          // 获取参数页面链接
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ParamsPage()),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.manualFetchParams),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // ── EasyTier 隧道配置 ──
          _buildSectionHeader(l10n.tunnelConfig, Icons.vpn_lock),
          const SizedBox(height: 8),
          _buildParamField(
            label: l10n.sharedKey,
            hint: l10n.sharedKeyHint,
            controller: _etSecretKeyController,
            icon: Icons.key,
            obscureText: true,
          ),
          const SizedBox(height: 8),
          _buildParamField(
            label: l10n.speedLimit,
            hint: l10n.speedLimitHint,
            controller: _etSpeedLimitController,
            icon: Icons.speed,
          ),
          const SizedBox(height: 12),
          // 开关项
          SwitchListTile(
            title: Text(l10n.enableIpv6),
            subtitle: Text(l10n.enableIpv6Subtitle),
            value: _etEnableIpv6,
            onChanged: (v) => setState(() => _etEnableIpv6 = v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: Text(l10n.enableWebDownload),
            subtitle: Text(l10n.enableWebDownloadSubtitle),
            value: _etEnableWebDl,
            onChanged: (v) => setState(() => _etEnableWebDl = v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: Text(l10n.useCustomConfig),
            subtitle: Text(l10n.useCustomConfigSubtitle),
            value: _etEnableUserConf,
            onChanged: (v) => setState(() => _etEnableUserConf = v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (_etEnableUserConf) ...[
            const SizedBox(height: 8),
            _buildParamField(
              label: l10n.customConfigPath,
              hint: l10n.customConfigPathHint,
              controller: _etUserConfPathController,
              icon: Icons.file_present,
            ),
          ],

          // ── 系统设置（新增） ──
          const SizedBox(height: 24),
          const Divider(),
          _buildSectionHeader(l10n.systemSettings, Icons.desktop_windows),
          const SizedBox(height: 8),
          // 开机自启开关
          SwitchListTile(
            title: Text(l10n.launchAtStartupTitle),
            subtitle: Text(_autoStartSupported
                ? l10n.launchAtStartupSubtitle
                : l10n.launchAtStartupNotSupported),
            value: _autoStartEnabled,
            onChanged: _autoStartSupported ? _onAutoStartChanged : null,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          // 关闭时最小化至托盘开关
          SwitchListTile(
            title: Text(l10n.minimizeToTrayTitle),
            subtitle: Text(_traySupported
                ? l10n.minimizeToTraySubtitle
                : l10n.minimizeToTrayNotSupported),
            value: _minimizeToTray,
            onChanged: _traySupported ? _onMinimizeToTrayChanged : null,
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 24),
          const Divider(),

          // ── 配置管理 ──
          _buildSectionHeader(l10n.configManagement, Icons.manage_search),
          const SizedBox(height: 8),
          // 清除配置
          OutlinedButton.icon(
            onPressed: _clearConfig,
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            label: Text(l10n.clearAllConfig),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          // 打开配置目录
          OutlinedButton.icon(
            onPressed: _openConfigDir,
            icon: const Icon(Icons.folder_open),
            label: Text(l10n.openConfigDir),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  /// 参数输入框
  Widget _buildParamField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  /// 开机自启开关切换
  Future<void> _onAutoStartChanged(bool value) async {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(configStoreProvider).valueOrNull;
    final sys = ref.read(systemIntegrationServiceProvider);
    final prev = _autoStartEnabled;

    // 乐观更新 UI（即时反馈）
    setState(() => _autoStartEnabled = value);

    try {
      await sys.setAutoStart(value);
      // 持久化用户选择
      if (config != null) config.launchAtStartup = value;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            value ? l10n.launchAtStartupEnabled : l10n.launchAtStartupDisabled,
          )),
        );
      }
    } catch (e) {
      // 失败回滚 UI
      if (mounted) {
        setState(() => _autoStartEnabled = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.launchAtStartupFailed}: $e')),
        );
      }
    }
  }

  /// 最小化至托盘开关切换
  ///
  /// 仅持久化配置，当前会话即时生效（onWindowClose 读取此配置）。
  /// setPreventClose 始终为 true，无需在此调用。
  Future<void> _onMinimizeToTrayChanged(bool value) async {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(configStoreProvider).valueOrNull;
    final prev = _minimizeToTray;

    setState(() => _minimizeToTray = value);

    try {
      if (config != null) config.minimizeToTray = value;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            value ? l10n.minimizeToTrayEnabled : l10n.minimizeToTrayDisabled,
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _minimizeToTray = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.minimizeToTrayFailed}: $e')),
        );
      }
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      config
        ..esurfingUrl = _esurfingUrlController.text.trim()
        ..wlanAcIp = _wlanAcIpController.text.trim()
        ..wlanUserIp = _wlanUserIpController.text.trim()
        ..etSecretKey = _etSecretKeyController.text.trim()
        ..etSpeedLimit = _etSpeedLimitController.text.trim()
        ..etEnableIpv6 = _etEnableIpv6
        ..etEnableWebDl = _etEnableWebDl
        ..etEnableUserConf = _etEnableUserConf
        ..etUserConfPath = _etUserConfPathController.text.trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 自动获取参数
  Future<void> _fetchParams() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final params = await repo.fetchEsurfingParams();

      if (!mounted) return;

      _esurfingUrlController.text = params.esurfingUrl;
      _wlanAcIpController.text = params.wlanAcIp;
      _wlanUserIpController.text = params.wlanUserIp;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paramsFetchSuccess)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.paramsFetchFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 清除配置
  Future<void> _clearConfig() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmClear),
        content: Text(l10n.confirmClearContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final config = ref.read(configStoreProvider).valueOrNull;
      if (config == null) return;

      await config.clearAll();

      // 重置表单
      _esurfingUrlController.clear();
      _wlanAcIpController.clear();
      _wlanUserIpController.clear();
      _etSecretKeyController.text = EsurfingApi.etDefaultSecret;
      _etSpeedLimitController.clear();
      _etUserConfPathController.clear();
      setState(() {
        _etEnableIpv6 = false;
        _etEnableWebDl = false;
        _etEnableUserConf = false;
        _minimizeToTray = true;   // 清除后恢复默认（true）
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.configCleared)),
        );
      }
    }
  }

  /// 打开配置目录
  Future<void> _openConfigDir() async {
    final l10n = AppLocalizations.of(context);
    try {
      final platform = ref.read(platformServiceProvider);
      final appDataDir = await platform.getAppDataDir();

      if (Platform.isWindows) {
        await Process.run('explorer', [appDataDir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [appDataDir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [appDataDir]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.configDir}: $appDataDir')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.cannotOpenConfigDir}: $e')),
        );
      }
    }
  }
}
