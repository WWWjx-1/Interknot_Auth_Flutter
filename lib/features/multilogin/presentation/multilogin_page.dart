/// 多拨页面
///
/// 对应原 Python `Setting.py` 中的多拨 tab：
/// - 动态 tab（添加/删除/切换）
/// - 每个 tab 含 IP、账号、密码三个输入框
/// - 右键删除 tab
/// - 串行登录/登出按钮
/// - 登录结果汇总表格
///
/// 遵循 Flutter 陷阱清单：
/// - setState 前检查 mounted
/// - 列表项给 Key
/// - 静态 widget 用 const
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../application/multilogin_controller.dart';

/// 多拨页面
class MultiloginPage extends ConsumerStatefulWidget {
  const MultiloginPage({super.key});

  @override
  ConsumerState<MultiloginPage> createState() => _MultiloginPageState();
}

class _MultiloginPageState extends ConsumerState<MultiloginPage> {
  /// 每个 tab 的输入控制器映射
  final Map<int, _TabControllers> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  _TabControllers _getControllers(int tabId, MultiloginTabConfig tab) {
    if (!_controllers.containsKey(tabId)) {
      _controllers[tabId] = _TabControllers(
        ip: TextEditingController(text: tab.ip),
        account: TextEditingController(text: tab.account),
        password: TextEditingController(text: tab.password),
      );
    }
    return _controllers[tabId]!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final multiloginState = ref.watch(multiloginControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.multiloginTitle),
        actions: [
          if (multiloginState.tabs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addTab,
              onPressed: multiloginState.isLoggingIn
                  ? null
                  : () => _showAddTabDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 操作栏 ──
          if (multiloginState.tabs.isNotEmpty)
            _buildActionBar(multiloginState, colorScheme),

          // ── 状态消息 ──
          if (multiloginState.statusMessage.isNotEmpty)
            _buildStatusBanner(multiloginState, colorScheme),

          // ── Tab 列表 ──
          Expanded(
            child: multiloginState.tabs.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : _buildTabList(multiloginState, theme, colorScheme),
          ),
        ],
      ),
      floatingActionButton: multiloginState.tabs.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTabDialog(),
              icon: const Icon(Icons.add),
              label: Text(l10n.addMultilogin),
            )
          : null,
    );
  }

  /// 操作栏（登录/登出按钮 + 统计）
  Widget _buildActionBar(MultiloginState state, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // 登录按钮
          ElevatedButton.icon(
            onPressed: state.isLoggingIn ? null : () => _handleLoginAll(),
            icon: state.isLoggingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(state.isLoggingIn ? l10n.loggingIn : l10n.loginAll),
          ),
          const SizedBox(width: 8),
          // 登出按钮
          OutlinedButton.icon(
            onPressed: state.isLoggingIn ? null : () => _handleLogoutAll(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.logoutAll),
          ),
          const Spacer(),
          // 统计
          if (state.successCount > 0 || state.failCount > 0)
            Text(
              l10n.successFailFormat(state.successCount, state.failCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  /// 状态横幅
  Widget _buildStatusBanner(MultiloginState state, ColorScheme colorScheme) {
    final isError = state.statusMessage.contains('失败') ||
        state.statusMessage.contains('异常');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isError
          ? colorScheme.errorContainer
          : colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 16,
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isError
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 72,
            color: colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMultiloginConfig,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addMultiloginHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(180),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddTabDialog(),
            icon: const Icon(Icons.add),
            label: Text(l10n.addMultilogin),
          ),
        ],
      ),
    );
  }

  /// Tab 列表
  Widget _buildTabList(
      MultiloginState state, ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.tabs.length + (state.results.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // 结果汇总卡片
        if (state.results.isNotEmpty && index == state.tabs.length) {
          return _buildResultsCard(state, theme, colorScheme);
        }

        final tab = state.tabs[index];
        final isCurrent = state.currentTabIndex == index;
        final result = state.results[tab.tabId];
        final controllers = _getControllers(tab.tabId, tab);

        return _MultiloginTabCard(
          key: ValueKey('ml_tab_${tab.tabId}'),
          tab: tab,
          index: index,
          isCurrent: isCurrent,
          result: result,
          controllers: controllers,
          onSave: () => _handleUpdateTab(tab.tabId, controllers),
          onDelete: () => _handleDeleteTab(tab.tabId),
        );
      },
    );
  }

  /// 登录结果汇总卡片
  Widget _buildResultsCard(
      MultiloginState state, ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.loginResults,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.successRate(state.successCount, state.failCount),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              ),
            const Divider(),
            ...state.results.entries.map((entry) {
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      result.success
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 18,
                      color: result.success
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${result.ip} | ${result.account}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      result.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: result.success
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── 操作处理 ────────────────────────────

  void _showAddTabDialog() {
    final l10n = AppLocalizations.of(context);
    final ipCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addMultiloginDialog),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipCtrl,
              decoration: InputDecoration(
                labelText: l10n.ipAddress,
                hintText: l10n.ipAddressHint,
                prefixIcon: const Icon(Icons.language),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountCtrl,
              decoration: InputDecoration(
                labelText: l10n.account,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ipCtrl.dispose();
              accountCtrl.dispose();
              passwordCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final ip = ipCtrl.text.trim();
              final account = accountCtrl.text.trim();
              final password = passwordCtrl.text;

              if (ip.isEmpty && account.isEmpty) {
                _showSnackBar(l10n.pleaseFillIpOrAccount);
                return;
              }

              try {
                await ref
                    .read(multiloginControllerProvider.notifier)
                    .addTab(ip: ip, account: account, password: password);
                if (ctx.mounted) Navigator.pop(ctx);
              } on MultiloginException catch (e) {
                _showSnackBar(e.message);
              }

              ipCtrl.dispose();
              accountCtrl.dispose();
              passwordCtrl.dispose();
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateTab(int tabId, _TabControllers controllers) async {
    try {
      await ref.read(multiloginControllerProvider.notifier).updateTab(
            tabId,
            ip: controllers.ip.text,
            account: controllers.account.text,
            password: controllers.password.text,
          );
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.tabUpdated);
    } on MultiloginException catch (e) {
      _showSnackBar(e.message);
    }
  }

  Future<void> _handleDeleteTab(int tabId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteTab),
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
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        _controllers.remove(tabId)?.dispose();
        await ref
            .read(multiloginControllerProvider.notifier)
            .removeTab(tabId);
      } on MultiloginException catch (e) {
        _showSnackBar(e.message);
      }
    }
  }

  Future<void> _handleLoginAll() async {
    try {
      await ref.read(multiloginControllerProvider.notifier).loginAll();
    } on MultiloginException catch (e) {
      _showSnackBar(e.message);
    }
  }

  Future<void> _handleLogoutAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmLogout),
        content: Text(l10n.confirmLogoutAll),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(multiloginControllerProvider.notifier).logoutAll();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

/// Tab 输入控制器组
class _TabControllers {
  final TextEditingController ip;
  final TextEditingController account;
  final TextEditingController password;

  _TabControllers({
    required this.ip,
    required this.account,
    required this.password,
  });

  void dispose() {
    ip.dispose();
    account.dispose();
    password.dispose();
  }
}

/// 多拨 Tab 卡片
class _MultiloginTabCard extends StatelessWidget {
  final MultiloginTabConfig tab;
  final int index;
  final bool isCurrent;
  final MultiloginTabResult? result;
  final _TabControllers controllers;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _MultiloginTabCard({
    super.key,
    required this.tab,
    required this.index,
    required this.isCurrent,
    required this.result,
    required this.controllers,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Tab ${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (result != null)
                  Icon(
                    result!.success ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: result!.success
                        ? AppColors.success
                        : AppColors.error,
                  ),
                const Spacer(),
                // 保存按钮
                IconButton(
                  icon: const Icon(Icons.save, size: 20),
                  tooltip: l10n.save,
                  onPressed: onSave,
                ),
                // 删除按钮
                IconButton(
                  key: const ValueKey('delete_btn'),
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: colorScheme.error),
                  tooltip: l10n.delete,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // IP 输入
            TextField(
              key: ValueKey('ip_${tab.tabId}'),
              controller: controllers.ip,
              decoration: InputDecoration(
                labelText: l10n.ipAddress,
                hintText: l10n.ipAddressHint,
                prefixIcon: const Icon(Icons.language, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),

            // 账号输入
            TextField(
              key: ValueKey('account_${tab.tabId}'),
              controller: controllers.account,
              decoration: InputDecoration(
                labelText: l10n.account,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),

            // 密码输入
            TextField(
              key: ValueKey('password_${tab.tabId}'),
              controller: controllers.password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
