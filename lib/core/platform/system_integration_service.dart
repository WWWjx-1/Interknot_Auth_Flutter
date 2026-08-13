/// 系统集成服务
///
/// M4 任务：统一管理桌面端系统集成能力。
///
/// 包含：
/// - 系统托盘（恢复/退出 + 最小化到托盘）
/// - 开机自启（Windows schtasks ONLOGON/HIGHEST 等价）
/// - 窗口控制（DPI/最小化）
/// - 文件锁防多开（PID 锁）
library;

import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/platform_service.dart';
import '../../core/storage/file_store.dart';
import '../../core/utils/logger.dart';

/// 系统集成服务
///
/// 封装所有桌面端系统集成能力，提供统一接口。
/// 移动端会跳过所有操作（由 PlatformService 判断）。
class SystemIntegrationService {
  final FileStore _fileStore;
  final PlatformService _platformService;
  final Logger _logger = Logger('SysInt');

  SystemIntegrationService({
    required FileStore fileStore,
    required PlatformService platformService,
  })  : _fileStore = fileStore,
        _platformService = platformService;

  // ──────────────────────────── 文件锁防多开 ────────────────────────────

  /// 尝试获取文件锁（防多开）
  ///
  /// 返回 `true` 表示获取成功，可以正常运行。
  /// 返回 `false` 表示已有实例在运行。
  Future<bool> tryAcquireLock() async {
    if (!_platformService.supportsSystemTray) {
      // 移动端无需文件锁
      return true;
    }

    try {
      final acquired = await _fileStore.tryLock();
      if (acquired) {
        _logger.info('文件锁获取成功');
        return true;
      } else {
        _logger.warn('文件锁获取失败：已有实例在运行');
        return false;
      }
    } catch (e, s) {
      _logger.error('文件锁异常', e, s);
      // 锁获取异常时允许运行（降级处理）
      return true;
    }
  }

  /// 释放文件锁
  Future<void> releaseLock() async {
    try {
      await _fileStore.unlock();
      _logger.info('文件锁已释放');
    } catch (e, s) {
      _logger.error('释放文件锁异常', e, s);
    }
  }

  // ──────────────────────────── 系统托盘 ────────────────────────────

  /// 初始化系统托盘
  ///
  /// [listener] 托盘事件监听器（实现 TrayListener 的对象）
  /// [showLabel] / [exitLabel] / [quickExitLabel] 菜单文案（由调用方传入 l10n）
  Future<void> initSystemTray({
    required TrayListener listener,
    required String showLabel,
    required String exitLabel,
    String? quickExitLabel,
  }) async {
    if (!_platformService.supportsSystemTray) {
      _logger.debug('当前平台不支持系统托盘');
      return;
    }

    // 拆分多个独立 try 块：任何一步失败都不阻塞后续步骤，
    // 避免出现"图标失败 → 菜单/监听器都没注册 → 用户无法恢复窗口"的情况。

    // 1. 设置图标（失败时回退到 yish.ico，再失败也继续后续步骤）
    try {
      await trayManager.setIcon('assets/icons/app_icon.ico');
    } catch (e, s) {
      _logger.error('设置托盘图标失败 (app_icon.ico)', e, s);
      try {
        await trayManager.setIcon('assets/icons/yish.ico');
        _logger.info('已回退使用 yish.ico 作为托盘图标');
      } catch (e2, s2) {
        _logger.error('回退托盘图标 (yish.ico) 也失败', e2, s2);
        // 即使图标失败，也继续设置 tooltip / 菜单 / 监听器
      }
    }

    // 2. 设置 tooltip（独立 try，失败不影响菜单）
    try {
      await trayManager.setToolTip('绳网认证 2.0');
    } catch (e, s) {
      _logger.error('设置托盘 tooltip 失败', e, s);
    }

    // 3. 设置右键菜单（独立 try，确保即使图标失败菜单也能用）
    try {
      final items = <MenuItem>[
        MenuItem(
          key: 'show',
          label: showLabel,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: exitLabel,
        ),
      ];
      // 可选：追加「直接退出」项
      if (quickExitLabel != null) {
        items.add(MenuItem.separator());
        items.add(MenuItem(
          key: 'quick_exit',
          label: quickExitLabel,
        ));
      }

      final menu = Menu(items: items);
      await trayManager.setContextMenu(menu);
    } catch (e, s) {
      _logger.error('设置托盘菜单失败', e, s);
    }

    // 4. 注册监听器（独立 try，确保即使图标/菜单失败也能收到点击事件）
    try {
      trayManager.addListener(listener);
    } catch (e, s) {
      _logger.error('注册托盘监听器失败', e, s);
    }

    _logger.info('系统托盘初始化流程完成');
  }

  /// 释放托盘资源
  Future<void> disposeTray({TrayListener? listener}) async {
    try {
      if (listener != null) {
        trayManager.removeListener(listener);
      }
      await trayManager.destroy();
      _logger.info('系统托盘已释放');
    } catch (e, s) {
      _logger.error('释放系统托盘异常', e, s);
    }
  }

  /// 主动弹出托盘右键菜单
  ///
  /// tray_manager 0.2.x 在 Windows 上不会自动弹上下文菜单，
  /// 必须由调用方在右键事件回调（onTrayIconRightMouseDown）中主动调用此方法。
  Future<void> popUpContextMenu() async {
    if (!_platformService.supportsSystemTray) return;

    try {
      await trayManager.popUpContextMenu();
    } catch (e, s) {
      _logger.error('弹出托盘菜单失败', e, s);
    }
  }

  // ──────────────────────────── 开机自启 ────────────────────────────

  /// 设置开机自启
  ///
  /// [enabled] true=启用, false=禁用
  Future<void> setAutoStart(bool enabled) async {
    if (!_platformService.supportsAutoStart) {
      _logger.debug('当前平台不支持开机自启');
      return;
    }

    try {
      launchAtStartup.setup(
        appName: 'InterKnot_Auth',
        appPath: Platform.resolvedExecutable,
      );

      if (enabled) {
        await launchAtStartup.enable();
        _logger.info('开机自启已启用');
      } else {
        await launchAtStartup.disable();
        _logger.info('开机自启已禁用');
      }
    } catch (e, s) {
      _logger.error('设置开机自启失败', e, s);
    }
  }

  /// 检查是否已启用开机自启
  Future<bool> isAutoStartEnabled() async {
    if (!_platformService.supportsAutoStart) return false;

    try {
      return await launchAtStartup.isEnabled();
    } catch (e, s) {
      _logger.error('检查开机自启状态失败', e, s);
      return false;
    }
  }

  // ──────────────────────────── 窗口控制 ────────────────────────────

  /// 最小化到系统托盘
  ///
  /// 隐藏窗口，保持在托盘运行。
  /// 如果托盘图标初始化失败，这里会兜底尝试重新设置图标，
  /// 防止"窗口藏起来但托盘没图标 → 用户找不到恢复入口"。
  Future<void> minimizeToTray() async {
    if (!_platformService.supportsSystemTray) return;

    try {
      // 兜底：若初始化时图标未成功设置，这里再尝试一次，
      // 保证隐藏窗口前托盘图标是可见的。
      try {
        await trayManager.setIcon('assets/icons/app_icon.ico');
      } catch (e, s) {
        _logger.warn('最小化到托盘前重设图标失败（忽略，继续隐藏窗口）：$e\n$s');
      }

      await windowManager.hide();
      _logger.debug('窗口已最小化到托盘');
    } catch (e, s) {
      _logger.error('最小化到托盘失败', e, s);
      // 兜底：若 hide 也失败，至少保证窗口可见，避免彻底消失
      try {
        await windowManager.show();
      } catch (_) {}
    }
  }

  /// 从托盘恢复窗口
  Future<void> restoreFromTray() async {
    if (!_platformService.supportsSystemTray) return;

    try {
      await windowManager.show();
      await windowManager.focus();
      _logger.debug('窗口已从托盘恢复');
    } catch (e, s) {
      _logger.error('从托盘恢复失败', e, s);
    }
  }

  /// 设置关闭按钮行为：true = 关闭时最小化到托盘，false = 直接退出
  Future<void> setPreventClose(bool prevent) async {
    if (!_platformService.supportsSystemTray) return;

    await windowManager.setPreventClose(prevent);
    _logger.debug('窗口关闭行为: ${prevent ? "最小化到托盘" : "直接退出"}');
  }

  /// 注册窗口事件监听器
  void addWindowListener(WindowListener listener) {
    if (_platformService.supportsSystemTray) {
      windowManager.addListener(listener);
    }
  }

  /// 移除窗口事件监听器
  void removeWindowListener(WindowListener listener) {
    if (_platformService.supportsSystemTray) {
      windowManager.removeListener(listener);
    }
  }
}
