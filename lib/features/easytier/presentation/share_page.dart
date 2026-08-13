/// EasyTier 共享页面
///
/// 对应原项目 EasyTier 共享/隧道双 tab 中的共享功能：
/// - 显示共享状态
/// - 显示连接信息（网络名、密钥、端口）
/// - 启动/停止共享
/// - 日志列表
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../application/easytier_controller.dart';

/// 共享页面
class SharePage extends ConsumerStatefulWidget {
  const SharePage({super.key});

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  final _secretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _secretController.text = EasyTierConstants.defaultSecret;
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(platformServiceProvider);

    if (!platform.supportsEasyTier) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.share)),
        body: Center(child: Text(l10n.easytierDesktopOnly)),
      );
    }

    final state = ref.watch(easytierControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.easytierShare),
        actions: [
          if (state.isRunning && state.mode == EasyTierMode.server)
            IconButton(
              icon: const Icon(Icons.dashboard),
              tooltip: l10n.dashboard,
              onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态卡片
            _buildStatusCard(context, state),
            const SizedBox(height: 16),

            // 配置信息
            _buildConfigCard(context),
            const SizedBox(height: 16),

            // 操作按钮
            _buildActionButton(context, state),
            const SizedBox(height: 16),

            // 日志列表
            _buildLogSection(context, state),
          ],
        ),
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.isRunning ? Icons.check_circle : Icons.cancel_outlined,
                  color: state.isRunning ? Colors.green : colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isRunning ? l10n.shareRunning : l10n.shareNotRunning,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            if (state.isRunning) ...[
              const SizedBox(height: 8),
              Text(
                'PID: ${state.pid ?? "?"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.status == EasyTierStatus.error) ...[
              const SizedBox(height: 8),
              Text(
                state.statusMessage,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 配置卡片
  Widget _buildConfigCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareConfig,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secretController,
              decoration: InputDecoration(
                labelText: l10n.networkKey,
                hintText: l10n.networkKeyHint,
                helperText: l10n.networkKeyHelper,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.key),
              ),
              onChanged: (v) {
                // 密钥将在启动时应用
              },
            ),
            const SizedBox(height: 12),
            _buildInfoRow(context, l10n.networkName, 'InterKnot'),
            _buildInfoRow(context, l10n.defaultPort, '${EasyTierConstants.defaultPort}'),
            _buildInfoRow(context, l10n.virtualIp, EasyTierConstants.virtualIp),
            _buildInfoRow(context, l10n.rpcPort, '${EasyTierConstants.rpcPort}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    final isRunning = state.isRunning && state.mode == EasyTierMode.server;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
        label: Text(isRunning ? l10n.stopShare : l10n.startShare),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isRunning
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          if (isRunning) {
            ref.read(easytierControllerProvider.notifier).stop();
          } else {
            // 应用密钥配置
            final easytierProcess = ref.read(easytierProcessProvider);
            easytierProcess.setSecretKey(_secretController.text.trim());
            ref.read(easytierControllerProvider.notifier).startShare();
          }
        },
      ),
    );
  }

  /// 日志区域
  Widget _buildLogSection(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.runningLogs,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (state.logLines.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(easytierControllerProvider.notifier).stop();
                },
                child: Text(l10n.clear),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: state.logLines.isEmpty
              ? Center(child: Text(l10n.noLogs))
              : ListView.builder(
                  itemCount: state.logLines.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      child: Text(
                        state.logLines[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
