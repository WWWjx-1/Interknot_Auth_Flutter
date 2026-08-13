/// 登录参数获取页面
///
/// 对应原 Python `Get_Userip_Thread` 的参数获取流程：
/// - 点击获取：GET 189.cn → 重定向 → 正则解析参数
/// - 显示解析结果（esurfingurl, wlanacip, wlanuserip）
/// - 允许手动编辑后保存到配置
///
/// 也对应原 Setting.py 中「自动获取」按钮的功能。
///
/// 遵循 Flutter 陷阱清单：
/// - 异步间隙后检查 mounted
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/esurfing_api.dart';

/// 参数获取页面
class ParamsPage extends ConsumerStatefulWidget {
  const ParamsPage({super.key});

  @override
  ConsumerState<ParamsPage> createState() => _ParamsPageState();
}

class _ParamsPageState extends ConsumerState<ParamsPage> {
  final _esurfingUrlController = TextEditingController();
  final _wlanAcIpController = TextEditingController();
  final _wlanUserIpController = TextEditingController();

  bool _isFetching = false;
  String _statusMessage = ''; // 将在 build 中通过 l10n 设置默认值

  @override
  void dispose() {
    _esurfingUrlController.dispose();
    _wlanAcIpController.dispose();
    _wlanUserIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fetchParamsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.saveToConfig,
            onPressed: _isFetching ? null : _saveToConfig,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 说明卡片 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.paramsInfo,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.paramsInfoContent,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 获取按钮 ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isFetching ? null : _fetchParams,
              icon: _isFetching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(_isFetching ? l10n.fetchingParams : l10n.fetchParamsButton),
            ),
          ),
          const SizedBox(height: 12),

          // ── 状态消息 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusMessage.contains(l10n.fetchSuccess)
                  ? colorScheme.primaryContainer.withAlpha(80)
                  : _statusMessage.contains(l10n.fetchFailed) || _statusMessage.contains(l10n.fetchException)
                      ? colorScheme.errorContainer.withAlpha(80)
                      : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusMessage.contains(l10n.fetchSuccess)
                    ? AppColors.success
                    : _statusMessage.contains(l10n.fetchFailed) || _statusMessage.contains(l10n.fetchException)
                        ? AppColors.error
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 参数显示/编辑区 ──
          _buildSectionHeader(l10n.portalParams, Icons.router),
          const SizedBox(height: 8),

          _buildParamField(
            label: l10n.portalAddress,
            hint: l10n.portalAddressHint,
            controller: _esurfingUrlController,
            icon: Icons.router,
          ),
          const SizedBox(height: 12),

          _buildParamField(
            label: l10n.acIp,
            hint: l10n.acIpHint,
            controller: _wlanAcIpController,
            icon: Icons.wifi,
          ),
          const SizedBox(height: 12),

          _buildParamField(
            label: l10n.userIp,
            hint: l10n.currentDeviceIp,
            controller: _wlanUserIpController,
            icon: Icons.computer,
          ),
          const SizedBox(height: 24),

          // ── 操作按钮 ──
          _buildSectionHeader(l10n.actions, Icons.build),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isFetching ? null : _clearFields,
                  icon: const Icon(Icons.clear_all),
                  label: Text(l10n.clearFields),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isFetching ? null : _saveToConfig,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.saveToConfig),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 原始 URL 显示 ──
          _buildSectionHeader(l10n.debugInfo, Icons.bug_report),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fetchUrl,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    EsurfingApi.getParamsUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildParamField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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

  /// 获取参数（对应 Get_Userip_Thread）
  Future<void> _fetchParams() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isFetching = true;
      _statusMessage = l10n.connecting189;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final params = await repo.fetchEsurfingParams();

      if (!mounted) return;

      _esurfingUrlController.text = params.esurfingUrl;
      _wlanAcIpController.text = params.wlanAcIp;
      _wlanUserIpController.text = params.wlanUserIp;

      setState(() {
        _statusMessage = '${l10n.fetchSuccess}'
            '\nesurfingurl: ${params.esurfingUrl}'
            '\nwlanacip: ${params.wlanAcIp}'
            '\nwlanuserip: ${params.wlanUserIp}';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '${l10n.fetchFailed}: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '${l10n.fetchException}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  /// 保存参数到配置
  void _saveToConfig() {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null || !mounted) return;

    config
      ..esurfingUrl = _esurfingUrlController.text.trim()
      ..wlanAcIp = _wlanAcIpController.text.trim()
      ..wlanUserIp = _wlanUserIpController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.paramsSavedToConfig)),
    );
  }

  /// 清空所有字段
  void _clearFields() {
    final l10n = AppLocalizations.of(context);
    _esurfingUrlController.clear();
    _wlanAcIpController.clear();
    _wlanUserIpController.clear();
    setState(() {
      _statusMessage = l10n.clearedRetry;
    });
  }
}
