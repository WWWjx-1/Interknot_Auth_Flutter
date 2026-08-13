/// 看门狗状态指示器
///
/// 显示看门狗的当前运行状态和冷却倒计时。
/// 可点击切换看门狗的启用/停用。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../application/watchdog_controller.dart';

/// 看门狗状态指示器 Widget
///
/// 显示在状态栏/工具栏中，指示看门狗当前状态：
/// - 未启动：灰色盾牌图标 + "看门狗: 未启用"
/// - 运行中：绿色盾牌图标 + "看门狗: 运行中"
/// - 检测中：蓝色旋转图标 + "检测中..."
/// - 冷却中：橙色图标 + "冷却中 Xs"
/// - 错误：红色图标 + 错误信息
class WatchdogStatusWidget extends ConsumerWidget {
  const WatchdogStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(watchdogControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 确定显示状态
    final (IconData icon, Color color, String text) = switch (state) {
      WatchdogState(isRunning: false) => (
          Icons.shield_outlined,
          colorScheme.onSurfaceVariant.withAlpha(160),
          l10n.watchdogNotEnabled,
        ),
      WatchdogState(
        isRunning: true,
        cooldownSeconds: > 0,
        statusMessage: final msg,
      ) => (
          Icons.timer_outlined,
          Colors.orange,
          msg,
        ),
      WatchdogState(
        isRunning: true,
        isChecking: true,
      ) => (
          Icons.sync,
          Colors.blue,
          l10n.watchdogChecking,
        ),
      WatchdogState(
        isRunning: true,
        connectionStatus: WatchdogConnectionStatus.connected,
      ) => (
          Icons.shield,
          Colors.green,
          l10n.watchdogRunning,
        ),
      WatchdogState(
        isRunning: true,
        connectionStatus: WatchdogConnectionStatus.disconnected,
      ) => (
          Icons.warning_amber_rounded,
          Colors.orange,
          l10n.watchdogDisconnected,
        ),
      _ => (
          Icons.shield_outlined,
          colorScheme.onSurfaceVariant,
          l10n.watchdogUnknown,
        ),
    };

    return InkWell(
      onTap: () => _toggleWatchdog(ref),
      borderRadius: BorderRadius.circular(20),
      child: Tooltip(
        message: state.isRunning ? l10n.watchdogDisable : l10n.watchdogEnable,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换看门狗启用/停用
  void _toggleWatchdog(WidgetRef ref) {
    final config = ref.read(configStoreProvider).valueOrNull;
    if (config == null) return;

    final state = ref.read(watchdogControllerProvider);
    if (state.isRunning) {
      // 停用看门狗
      ref.read(watchdogControllerProvider.notifier).stop();
      config.enableWatchdog = false;
    } else {
      // 启用看门狗
      config.enableWatchdog = true;
      ref.read(watchdogControllerProvider.notifier).start();
    }
  }
}
