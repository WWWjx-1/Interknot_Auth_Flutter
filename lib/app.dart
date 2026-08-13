/// 应用根 Widget：MaterialApp.router + 主题 + dynamic_color
///
/// M4 增强：启动后初始化系统集成（托盘、文件锁、开机自启、看门狗、更新检查）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/core.dart';
import 'features/updater/application/updater_controller.dart';
import 'features/watchdog/application/watchdog_controller.dart';
import 'l10n/app_localizations.dart';
import 'shared/router/app_router.dart';
import 'shared/theme/app_theme.dart';

final _logger = Logger('App');

/// 全局 NavigatorState Key
///
/// 用于在 `_InterKnotAppState` 的回调（如 `onTrayMenuItemClick`、
/// `_initializeSystemIntegration`、`onWindowClose`）中拿到一个 context，
/// 该 context 的祖先链包含 `MaterialApp` / `Localizations`，可以：
/// - 用 `AppLocalizations.of(ctx)` 拿到正确的本地化字符串
/// - 用 `showDialog(context: ctx)` 弹出对话框（依赖 Navigator & MaterialLocalizations）
///
/// 不能直接用 `State.context`，因为 `_InterKnotAppState.context` 的祖先链
/// 不含 `MaterialApp`（`MaterialApp` 是 `build` 返回的子节点，不是祖先）。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 应用入口 Widget
///
/// 同时实现 TrayListener 和 WindowListener 以接收系统托盘和窗口事件。
class InterKnotApp extends ConsumerStatefulWidget {
  const InterKnotApp({super.key});

  @override
  ConsumerState<InterKnotApp> createState() => _InterKnotAppState();
}

class _InterKnotAppState extends ConsumerState<InterKnotApp>
    with TrayListener, WindowListener {
  SystemIntegrationService? _systemIntegration;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 在下一帧执行初始化（确保 ProviderScope 就绪）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSystemIntegration();
    });
  }

  @override
  void dispose() {
    // dispose 是同步的，但 disposeTray / releaseLock 是异步 Future。
    // 用立即调用的 async 闭包做异步清理，不阻塞 dispose，避免资源泄漏。
    final sys = _systemIntegration;
    if (sys != null) {
      () async {
        await sys.disposeTray(listener: this);
        sys.removeWindowListener(this);
        await sys.releaseLock();
      }();
    }
    super.dispose();
  }

  // ──────────────────────────── M4 系统集成初始化 ────────────────────────────

  Future<void> _initializeSystemIntegration() async {
    if (_initialized) return;
    _initialized = true;

    _logger.info('系统集成初始化开始...');

    // 改用全局 Provider，确保设置页与 app 用同一实例
    _systemIntegration = ref.read(systemIntegrationServiceProvider);
    final platform = ref.read(platformServiceProvider);

    // 1. 文件锁防多开
    final lockAcquired = await _systemIntegration!.tryAcquireLock();
    if (!lockAcquired) {
      _logger.warn('检测到已有实例在运行');
      if (mounted) {
        _showAlreadyRunningDialog();
      }
      return;
    }
    _logger.info('步骤1完成：文件锁已获取');

    // 2. 初始化系统托盘（在拿到 labels 前先记日志，方便排查）
    _logger.info('步骤2开始：初始化系统托盘 (supportsSystemTray=${platform.supportsSystemTray})');
    if (platform.supportsSystemTray) {
      // 在 try 内部取 l10n，防止异常打断整个初始化链
      // 兜底文案必须齐全（包括 quickExitLabel），否则菜单会缺少"直接退出"项
      String showLabel = '显示主窗口';
      String exitLabel = '退出';
      String quickExitLabel = '直接退出';
      try {
        // 用 navigatorKey 的 context，而不是 State.context。
        // State.context 的祖先链不含 MaterialApp，AppLocalizations.of 会返回 null。
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null) {
          final l10n = AppLocalizations.of(ctx);
          showLabel = l10n.trayShowWindow;
          exitLabel = l10n.trayExit;
          quickExitLabel = l10n.trayQuickExit;
        }
      } catch (e) {
        _logger.warn('读取托盘 l10n 失败，使用兜底文案：$e');
      }

      try {
        await _systemIntegration!.initSystemTray(
          listener: this,
          showLabel: showLabel,
          exitLabel: exitLabel,
          quickExitLabel: quickExitLabel,
        );
      } catch (e, s) {
        _logger.error('initSystemTray 顶层异常（已尝试内部 try 隔离）', e, s);
      }

      // 始终拦截关闭按钮，由 onWindowClose 按配置分流
      // （setPreventClose(true) 后点 × 不会真关，触发 onWindowClose）
      try {
        await _systemIntegration!.setPreventClose(true);
        _systemIntegration!.addWindowListener(this);
      } catch (e, s) {
        _logger.error('设置 setPreventClose / addWindowListener 失败', e, s);
      }
    }
    _logger.info('步骤2完成：托盘初始化流程结束');

    // 3. 检查并设置开机自启
    try {
      await _initAutoStart();
    } catch (e, s) {
      _logger.error('开机自启初始化失败', e, s);
    }

    // 4. 执行数据迁移（M1）
    _initDataMigration();

    // 5. 启动更新检查
    _initUpdateCheck();

    // 6. 启动看门狗（若配置启用）
    _initWatchdog();

    _logger.info('M4 系统集成初始化完成');
  }

  /// 显示"已有实例在运行"对话框
  void _showAlreadyRunningDialog() {
    String title = '已有实例运行';
    String content = '绳网认证 2.0 已在运行，请勿重复启动。';
    String okLabel = '确定';
    final ctx = appNavigatorKey.currentContext;
    try {
      if (ctx != null) {
        final l10n = AppLocalizations.of(ctx);
        title = l10n.alreadyRunningTitle;
        content = l10n.alreadyRunningContent;
        okLabel = l10n.ok;
      }
    } catch (e) {
      _logger.warn('读取"已运行"对话框 l10n 失败，使用兜底文案：$e');
    }

    if (ctx == null) {
      _logger.warn('navigatorKey.currentContext 为空，直接退出');
      _exitApp();
      return;
    }

    try {
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _exitApp();
              },
              child: Text(okLabel),
            ),
          ],
        ),
      );
    } catch (e, s) {
      _logger.error('显示"已运行"对话框失败', e, s);
      _exitApp();
    }
  }

  // ──────────────────────────── TrayListener 回调 ────────────────────────────

  /// 左键单击托盘图标 → 恢复窗口
  @override
  void onTrayIconMouseDown() {
    _systemIntegration?.restoreFromTray();
  }

  @override
  void onTrayIconMouseUp() {}

  /// 右键按下托盘图标 → 主动弹出上下文菜单
  ///
  /// 说明：tray_manager 0.2.x 在 Windows 上不会自动弹出 setContextMenu 注册的菜单，
  /// 必须由 listener 在右键事件里主动调用 popUpContextMenu()。
  /// 这里选 RightMouseDown（按下时即弹），符合 Windows 通知区域图标的标准行为。
  @override
  void onTrayIconRightMouseDown() {
    _systemIntegration?.popUpContextMenu();
  }

  /// 右键抬起（保留钩子，Windows 上 menu 已在 down 时弹出，这里空实现避免重复弹）
  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    _logger.info('托盘菜单项被点击：key=${menuItem.key}');
    switch (menuItem.key) {
      case 'show':
        _systemIntegration?.restoreFromTray();
        break;
      case 'exit':
        _onTrayExit();          // 弹确认框后退出（防误触）
        break;
      case 'quick_exit':       // 直接退出，不弹框
        _exitApp();
        break;
      default:
        _logger.warn('未处理的托盘菜单项：${menuItem.key}');
    }
  }

  // ──────────────────────────── WindowListener 回调 ────────────────────────────

  @override
  void onWindowClose() {
    // 按配置分流：true=最小化到托盘，false=直接退出
    final config = ref.read(configStoreProvider).valueOrNull;
    final toTray = config?.minimizeToTray ?? true;

    if (toTray) {
      _systemIntegration?.minimizeToTray();
    } else {
      _exitApp();   // 走统一退出路径，清理托盘/锁/监听器后 exit(0)
    }
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowEvent(String eventName) {}

  // ──────────────────────────── 托盘退出 ────────────────────────────

  void _onTrayExit() {
    _showExitConfirmDialog();
  }

  void _showExitConfirmDialog() {
    // 兜底文案，避免 l10n 未就绪时 AppLocalizations.of(context) 抛 Null 异常
    String confirmTitle = '确认退出';
    String confirmContent = '确定要退出绳网认证吗？';
    String cancelLabel = '取消';
    String exitLabel = '退出';
    final ctx = appNavigatorKey.currentContext;
    try {
      if (ctx != null) {
        final l10n = AppLocalizations.of(ctx);
        confirmTitle = l10n.confirmExitTitle;
        confirmContent = l10n.confirmExitContent;
        cancelLabel = l10n.cancel;
        exitLabel = l10n.exit;
      }
    } catch (e) {
      _logger.warn('读取退出对话框 l10n 失败，使用兜底文案：$e');
    }

    if (ctx == null) {
      _logger.warn('navigatorKey.currentContext 为空，直接退出');
      _exitApp();
      return;
    }

    try {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: Text(confirmTitle),
          content: Text(confirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(cancelLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _exitApp();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(exitLabel),
            ),
          ],
        ),
      );
    } catch (e, s) {
      _logger.error('显示退出确认对话框失败，直接退出', e, s);
      _exitApp();
    }
  }

  void _exitApp() {
    final sys = _systemIntegration;
    debugPrint('绳网认证 2.0 退出');
    if (sys == null) {
      exit(0);
    }
    // 异步清理完成后再 exit(0)，避免 disposeTray/releaseLock 被中断。
    // 用 scheduleMicrotask 确保当前 native 回调（如 onTrayMenuItemClick）先返回给
    // engine，再执行清理+退出，避免 menu 回调被 exit 打断导致菜单卡住。
    // ignore: dead_code
    scheduleMicrotask(() async {
      try {
        await sys.disposeTray(listener: this);
        sys.removeWindowListener(this);
        await sys.releaseLock();
      } catch (_) {}
      exit(0);
    });
  }

  // ──────────────────────────── 开机自启 ────────────────────────────

  Future<void> _initAutoStart() async {
    final platform = ref.read(platformServiceProvider);
    if (!platform.supportsAutoStart) {
      _logger.debug('当前平台不支持开机自启，跳过');
      return;
    }

    // 读取用户配置，按需注册/注销自启（不再硬编码 true）
    final config = ref.read(configStoreProvider).valueOrNull;
    final enabled = config?.launchAtStartup ?? false;

    await _systemIntegration!.setAutoStart(enabled);
    _logger.info('开机自启按配置设置：${enabled ? "已启用" : "已禁用"}');
  }

  // ──────────────────────────── 数据迁移 ────────────────────────────

  void _initDataMigration() {
    // M1 迁移工具在首次运行时自动执行
    // migration.dart 会在 configStore 初始化时检查 migrated 标记
    _logger.debug('数据迁移检查中...');
  }

  // ──────────────────────────── 更新检查 ────────────────────────────

  void _initUpdateCheck() {
    // 启动时自动检查更新（异步，不阻塞 UI）
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ref.read(updaterControllerProvider.notifier).checkUpdate();
      }
    });
  }

  // ──────────────────────────── 看门狗 ────────────────────────────

  void _initWatchdog() {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null) return;

    if (config.enableWatchdog) {
      _logger.info('看门狗已配置为启用，自动启动');
      ref.read(watchdogControllerProvider.notifier).start();
    }
  }

  // ──────────────────────────── Build ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        return MaterialApp.router(
          title: '绳网认证',
          debugShowCheckedModeBanner: false,
          // M7: l10n 国际化支持
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh'),
            Locale('en'),
          ],
          locale: const Locale('zh'),
          theme: AppTheme.buildLightTheme(lightColorScheme),
          darkTheme: AppTheme.buildDarkTheme(darkColorScheme),
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
