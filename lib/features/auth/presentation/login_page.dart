/// 登录页面
///
/// 对应原 Python MainWindow 的主界面：
/// - 账号下拉框（支持右键删除）
/// - 密码输入框
/// - 登录/登出按钮
/// - 复选框（记住密码/自动登录/看门狗/自动共享/t模式）
/// - 日志控制台
/// - 进度条
///
/// 遵循 Flutter 陷阱清单：
/// - setState 前检查 mounted
/// - 异步间隙后使用 context 前检查 mounted
/// - 列表项给 Key
/// - 静态 widget 用 const
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();

  bool _savePassword = false;
  bool _autoConnect = false;
  bool _enableWatchdog = false;
  bool _autoShare = false;
  bool _tMode = false;

  /// 是否支持 jar 登录（桌面端 true，移动端 false）
  bool _supportsJar = false;

  final List<String> _logLines = [];
  static const _maxLogLines = 1000;

  @override
  void initState() {
    super.initState();
    // 延迟加载配置（等 widget 构建完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
      _checkPlatformSupport();
    });
    // 注入日志回调
    Logger.onLog = (formatted) async {
      if (!mounted) return;
      setState(() {
        _logLines.add(formatted);
        if (_logLines.length > _maxLogLines) {
          _logLines.removeAt(0);
        }
      });
      // 自动滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    };
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    Logger.onLog = null;
    super.dispose();
  }

  /// 检查平台是否支持 jar 登录
  void _checkPlatformSupport() {
    if (!mounted) return;
    final platform = ref.read(platformServiceProvider);
    setState(() {
      _supportsJar = platform.supportsJarLogin;
    });
  }

  Future<void> _loadConfig() async {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null || !mounted) return;

    setState(() {
      _savePassword = config.savePassword;
      _autoConnect = config.autoConnect;
      _enableWatchdog = config.enableWatchdog;
      _autoShare = config.autoShare;
      _tMode = config.loginMode == 1;
    });

    // 恢复上次用户名
    final savedUser = config.username;
    if (savedUser != null && savedUser.isNotEmpty) {
      _userController.text = savedUser;
    }
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context);
    final user = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (user.isEmpty) {
      _addLog(LogLevel.warn, l10n.pleaseEnterAccount);
      return;
    }
    if (password.isEmpty) {
      _addLog(LogLevel.warn, l10n.pleaseEnterPassword);
      return;
    }

    // 保存配置
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null || !mounted) return;

    // 移动端：强制 t 模式（jar 不可用）
    final effectiveLoginMode = _supportsJar ? (_tMode ? 1 : 0) : 1;

    config
      ..savePassword = _savePassword
      ..autoConnect = _autoConnect
      ..enableWatchdog = _enableWatchdog
      ..autoShare = _autoShare
      ..loginMode = effectiveLoginMode
      ..username = user;

    await ref.read(authControllerProvider.notifier).login(
          user: user,
          password: password,
          loginMode: effectiveLoginMode,
        );
  }

  Future<void> _handleLogout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  void _addLog(LogLevel level, String message) {
    if (!mounted) return;
    final timestamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceFirst('T', ' ');
    setState(() {
      _logLines.add('$timestamp ${level.prefix} $message');
      if (_logLines.length > _maxLogLines) {
        _logLines.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isConnected = authState.status == AuthStatus.connected;
    final isLoggingIn = authState.status == AuthStatus.loggingIn ||
        authState.status == AuthStatus.fetchingParams;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitleVersion),
        centerTitle: true,
        actions: [
          // 多拨入口
          IconButton(
            icon: const Icon(Icons.dns),
            tooltip: l10n.multilogin,
            onPressed: () => context.push('/multilogin'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 登录表单 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 账号输入
                      _buildAccountField(colorScheme),
                      const SizedBox(height: 12),
                      // 密码输入
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 12),
                      // 复选框行
                      _buildCheckboxes(colorScheme),
                      const SizedBox(height: 16),
                      // 登录/登出按钮
                      _buildActionButton(
                        isConnected: isConnected,
                        isLoggingIn: isLoggingIn,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 状态栏 ──
            _buildStatusBar(authState, colorScheme),

            // ── 日志控制台 ──
            Expanded(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 12, right: 12, top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.terminal,
                              size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            l10n.logTitle,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.clear_all, size: 18),
                            tooltip: l10n.clearLogs,
                            onPressed: () {
                              setState(() => _logLines.clear());
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _logLines.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noLogs,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              itemCount: _logLines.length,
                              itemBuilder: (context, index) {
                                return _LogLine(
                                  key: ValueKey('log_$index'),
                                  text: _logLines[index],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建账号输入区域（下拉框 + 右侧删除按钮）
  Widget _buildAccountField(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final accountsAsync = ref.watch(secureAccountStoreProvider);
    // 使用 ref.read 触发异步加载
    return FutureBuilder<List<String>>(
      future: accountsAsync.listAccounts(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        return Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return accounts;
                  }
                  return accounts
                      .where((a) => a.contains(textEditingValue.text));
                },
                onSelected: (value) {
                  _userController.text = value;
                  // 自动填充密码
                  _fillPassword(value);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  controller.text = _userController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: l10n.account,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onChanged: (v) => _userController.text = v,
                    onSubmitted: (_) => _handleLogin(),
                  );
                },
              ),
            ),
            if (accounts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: l10n.deleteAccount,
                onPressed: () => _showDeleteAccountDialog(accounts),
              ),
          ],
        );
      },
    );
  }

  /// 自动填充密码
  Future<void> _fillPassword(String user) async {
    final password = await ref.read(secureAccountStoreProvider).read(user);
    if (password != null && mounted) {
      _passwordController.text = password;
    }
  }

  /// 显示删除账号对话框
  void _showDeleteAccountDialog(List<String> accounts) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.deleteAccountTitle),
        children: [
          for (final account in accounts)
            SimpleDialogOption(
              key: ValueKey('del_$account'),
              onPressed: () async {
                await ref.read(secureAccountStoreProvider).delete(account);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {});
                  _addLog(LogLevel.info, '${l10n.accountDeleted}: $account');
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(account),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建复选框行
  Widget _buildCheckboxes(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final checkboxes = <Widget>[
      _buildCheckbox(
        label: l10n.rememberPassword,
        value: _savePassword,
        onChanged: (v) => setState(() => _savePassword = v),
      ),
      _buildCheckbox(
        label: l10n.autoLogin,
        value: _autoConnect,
        onChanged: (v) => setState(() => _autoConnect = v),
      ),
      _buildCheckbox(
        label: l10n.watchdog,
        value: _enableWatchdog,
        onChanged: (v) => setState(() => _enableWatchdog = v),
      ),
      _buildCheckbox(
        label: l10n.autoShare,
        value: _autoShare,
        onChanged: (v) => setState(() => _autoShare = v),
      ),
    ];

    // 仅在桌面端显示 t 模式复选框（移动端始终走 HTTP 路径）
    if (_supportsJar) {
      checkboxes.add(
        _buildCheckbox(
          label: l10n.tMode,
          value: _tMode,
          onChanged: (v) => setState(() => _tMode = v),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: checkboxes,
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建登录/登出按钮
  Widget _buildActionButton({
    required bool isConnected,
    required bool isLoggingIn,
    required ColorScheme colorScheme,
  }) {
    final l10n = AppLocalizations.of(context);
    if (isLoggingIn) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(l10n.processing),
      );
    }

    if (isConnected) {
      return ElevatedButton.icon(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        icon: const Icon(Icons.logout),
        label: Text(l10n.logoff),
      );
    }

    return ElevatedButton.icon(
      onPressed: _handleLogin,
      icon: const Icon(Icons.login),
      label: Text(l10n.login),
    );
  }

  /// 构建状态栏
  Widget _buildStatusBar(
      AuthControllerState authState, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    Color statusColor;
    IconData statusIcon;

    switch (authState.status) {
      case AuthStatus.connected:
        statusColor = AppColors.connected;
        statusIcon = Icons.check_circle;
      case AuthStatus.loggingIn:
      case AuthStatus.fetchingParams:
        statusColor = AppColors.connecting;
        statusIcon = Icons.sync;
      case AuthStatus.error:
        statusColor = AppColors.error;
        statusIcon = Icons.error;
      case AuthStatus.disconnected:
        statusColor = AppColors.offline;
        statusIcon = Icons.cloud_off;
      case AuthStatus.idle:
        statusColor = AppColors.offline;
        statusIcon = Icons.cloud_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              authState.statusMessage.isNotEmpty
                  ? authState.statusMessage
                  : l10n.ready,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (authState.status == AuthStatus.connected &&
              authState.currentUser != null)
            Text(
              authState.currentUser!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.connected,
                    fontWeight: FontWeight.bold,
                  ),
            ),
        ],
      ),
    );
  }
}

/// 单行日志组件
class _LogLine extends StatelessWidget {
  final String text;
  const _LogLine({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? color;
    if (text.contains('[ERROR]')) {
      color = AppColors.error;
    } else if (text.contains('[WARN]')) {
      color = AppColors.warning;
    } else if (text.contains('[INFO]')) {
      color = AppColors.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
