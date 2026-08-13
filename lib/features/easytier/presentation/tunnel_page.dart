/// EasyTier 隧道页面
///
/// 对应原项目 EasyTier 共享/隧道双 tab 中的隧道功能：
/// - 输入对端 IP + 密钥
/// - 连接/断开隧道
/// - 显示连接状态
/// - 隧道日志列表
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../application/easytier_controller.dart';

/// 隧道页面
class TunnelPage extends ConsumerStatefulWidget {
  const TunnelPage({super.key});

  @override
  ConsumerState<TunnelPage> createState() => _TunnelPageState();
}

class _TunnelPageState extends ConsumerState<TunnelPage> {
  final _peerIpController = TextEditingController();
  final _secretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _secretController.text = EasyTierConstants.defaultSecret;
  }

  @override
  void dispose() {
    _peerIpController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(platformServiceProvider);

    if (!platform.supportsEasyTier) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tunnel)),
        body: Center(child: Text(l10n.easytierDesktopOnly)),
      );
    }

    final state = ref.watch(easytierControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.easytierTunnel),
        actions: [
          if (state.isRunning && state.mode == EasyTierMode.client)
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

            // 连接配置
            _buildConnectionCard(context, state),
            const SizedBox(height: 16),

            // 操作按钮
            _buildActionButton(context, state),
            const SizedBox(height: 16),

            // 隧道信息
            if (state.isRunning && state.mode == EasyTierMode.client) ...[
              _buildTunnelInfoCard(context, state),
              const SizedBox(height: 16),
            ],

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
                  state.isRunning && state.mode == EasyTierMode.client
                      ? Icons.link
                      : Icons.link_off,
                  color: state.isRunning && state.mode == EasyTierMode.client
                      ? Colors.green
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isRunning && state.mode == EasyTierMode.client
                      ? l10n.tunnelConnected
                      : l10n.tunnelNotConnected,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            if (state.isRunning && state.mode == EasyTierMode.client) ...[
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

  /// 连接配置卡片
  Widget _buildConnectionCard(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    final isConnected =
        state.isRunning && state.mode == EasyTierMode.client;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.connectionConfig,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _peerIpController,
              enabled: !isConnected,
              decoration: InputDecoration(
                labelText: l10n.peerIpAddress,
                hintText: l10n.peerIpHint,
                helperText: l10n.peerIpHelper,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.computer),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secretController,
              enabled: !isConnected,
              decoration: InputDecoration(
                labelText: l10n.networkKey,
                hintText: l10n.networkKeyHint,
                helperText: l10n.networkKeyMustMatch,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    final isConnected =
        state.isRunning && state.mode == EasyTierMode.client;
    final isLoading = state.status == EasyTierStatus.starting;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
        label: Text(isConnected ? l10n.disconnectTunnel : l10n.connectTunnel),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isConnected
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        onPressed: isLoading
            ? null
            : () {
                if (isConnected) {
                  ref.read(easytierControllerProvider.notifier).stop();
                } else {
                  final peerIp = _peerIpController.text.trim();
                  if (peerIp.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.pleaseEnterPeerIp)),
                    );
                    return;
                  }
                  ref.read(easytierControllerProvider.notifier).connectTunnel(
                        peerIp: peerIp,
                        secret: _secretController.text.trim(),
                      );
                }
              },
      ),
    );
  }

  /// 隧道信息卡片
  Widget _buildTunnelInfoCard(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tunnelInfo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(context, l10n.virtualIp, EasyTierConstants.virtualIp),
            _buildInfoRow(
                context, l10n.rpcPort, '${EasyTierConstants.rpcPort}'),
            if (state.peers.isNotEmpty) ...[
              const Divider(),
              Text(
                '${l10n.peerNodes} (${state.peers.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...state.peers.map((peer) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          peer.isConnected
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                          color: peer.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(peer.endpoint),
                        const Spacer(),
                        Text(
                          '${peer.latency}ms',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )),
            ],
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

  /// 日志区域
  Widget _buildLogSection(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tunnelLogs,
          style: Theme.of(context).textTheme.titleMedium,
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
