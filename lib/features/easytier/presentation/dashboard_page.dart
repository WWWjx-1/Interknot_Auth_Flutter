/// EasyTier Dashboard 页面
///
/// 对应原 Python `WebUI.py` :50000 HTTP 大屏/下载页。
/// 使用 Flutter 原生 UI + fl_chart 替代 WebUI 大屏。
///
/// 功能：
/// - 节点状态卡片（在线/离线/流量）
/// - 对等节点列表
/// - 流量实时折线图（fl_chart）
/// - 路由表
///
/// 移动端显示「仅桌面端可用」占位。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../l10n/app_localizations.dart';
import '../application/easytier_controller.dart';
import '../data/easytier_cli.dart';

/// Dashboard 页面
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.read(platformServiceProvider);

    // 移动端：仅桌面端可用
    if (!platform.supportsEasyTier) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.dashboard)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.desktop_windows_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.dashboardDesktopOnly,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.dashboardDesktopHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(easytierControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.easytierDashboard),
        actions: [
          if (state.isRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: l10n.stop,
              onPressed: () => ref.read(easytierControllerProvider.notifier).stop(),
            ),
        ],
      ),
      body: state.isRunning
          ? _buildRunningDashboard(context, state)
          : _buildIdleDashboard(context, state),
    );
  }

  /// 运行中的 Dashboard
  Widget _buildRunningDashboard(
      BuildContext context, EasyTierControllerState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态栏
          _buildStatusBar(context, state),
          const SizedBox(height: 16),

          // 节点卡片
          _buildNodeCards(context, state.nodes),
          const SizedBox(height: 16),

          // 流量图表
          _buildTrafficChart(context, state.nodes),
          const SizedBox(height: 16),

          // 对等节点列表
          _buildPeerList(context, state.peers),
          const SizedBox(height: 16),

          // 路由表
          _buildRouteTable(context, state.routes),
        ],
      ),
    );
  }

  /// 空闲状态的 Dashboard
  Widget _buildIdleDashboard(
      BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.easytierNotRunning,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (state.status == EasyTierStatus.error)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                state.statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startShare),
            onPressed: () =>
                ref.read(easytierControllerProvider.notifier).startShare(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── 状态栏 ────────────────────────────

  Widget _buildStatusBar(BuildContext context, EasyTierControllerState state) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.running,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Chip(
              avatar: Icon(
                state.mode == EasyTierMode.server
                    ? Icons.share
                    : Icons.vpn_lock,
                size: 16,
              ),
              label: Text(
                state.mode == EasyTierMode.server ? l10n.shareMode : l10n.tunnelMode,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'PID: ${state.pid ?? "?"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── 节点卡片 ────────────────────────────

  Widget _buildNodeCards(BuildContext context, List<EasyTierNodeInfo> nodes) {
    final l10n = AppLocalizations.of(context);
    if (nodes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: Text(l10n.noNodeData)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.networkNodes} (${nodes.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...nodes.map((node) => _buildNodeCard(context, node)),
      ],
    );
  }

  Widget _buildNodeCard(BuildContext context, EasyTierNodeInfo node) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node.isOnline ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.nodeName.isNotEmpty ? node.nodeName : node.nodeId,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  node.isOnline ? l10n.online : l10n.offline,
                  style: TextStyle(
                    color: node.isOnline ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(context, 'IPv4', node.ipv4),
                const SizedBox(width: 8),
                _buildInfoChip(context, l10n.peers, '${node.peerCount}'),
                const SizedBox(width: 8),
                _buildInfoChip(
                    context, l10n.traffic, '${node.totalTrafficMB.toStringAsFixed(1)} MB'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  // ──────────────────────────── 流量图表 ────────────────────────────

  Widget _buildTrafficChart(
      BuildContext context, List<EasyTierNodeInfo> nodes) {
    final l10n = AppLocalizations.of(context);
    final totalRx = nodes.fold<double>(0, (sum, n) => sum + n.rxBytes);
    final totalTx = nodes.fold<double>(0, (sum, n) => sum + n.txBytes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.networkTraffic,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTrafficLegend(context, l10n.download, totalRx, Colors.blue),
                const SizedBox(width: 24),
                _buildTrafficLegend(context, l10n.upload, totalTx, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: nodes.isEmpty
                  ? Center(child: Text(l10n.noTrafficData))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _maxTraffic(nodes),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalRx / (1024 * 1024),
                                color: Colors.blue,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: totalTx / (1024 * 1024),
                                color: Colors.green,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                            axisNameWidget: Text('MB'),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Text(''),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: _maxTraffic(nodes) / 4,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficLegend(
      BuildContext context, String label, double bytes, Color color) {
    final mb = bytes / (1024 * 1024);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${mb.toStringAsFixed(2)} MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  double _maxTraffic(List<EasyTierNodeInfo> nodes) {
    if (nodes.isEmpty) return 1;
    final maxBytes =
        nodes.fold<double>(0, (max, n) => n.rxBytes > max ? n.rxBytes : max);
    final maxMB = maxBytes / (1024 * 1024);
    return maxMB > 0 ? maxMB * 1.2 : 1;
  }

  // ──────────────────────────── 对等节点列表 ────────────────────────────

  Widget _buildPeerList(BuildContext context, List<EasyTierPeerInfo> peers) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.peerNodes} (${peers.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (peers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(l10n.noPeerConnected)),
            ),
          )
        else
          ...peers.map((peer) => _buildPeerCard(context, peer)),
      ],
    );
  }

  Widget _buildPeerCard(BuildContext context, EasyTierPeerInfo peer) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  peer.isConnected ? Icons.link : Icons.link_off,
                  size: 18,
                  color: peer.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    peer.peerName.isNotEmpty ? peer.peerName : peer.peerId,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${peer.latency}ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildInfoChip(context, l10n.endpoint, peer.endpoint),
                const SizedBox(width: 8),
                _buildInfoChip(context, 'IP', peer.ipv4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── 路由表 ────────────────────────────

  Widget _buildRouteTable(
      BuildContext context, List<EasyTierRouteInfo> routes) {
    final l10n = AppLocalizations.of(context);
    if (routes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.routeTable,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.routeDestination)),
                DataColumn(label: Text(l10n.routeGateway)),
                DataColumn(label: Text(l10n.routeInterface)),
                DataColumn(label: Text(l10n.routeMetric)),
                DataColumn(label: Text(l10n.routeStatus)),
              ],
              rows: routes.map((route) {
                return DataRow(cells: [
                  DataCell(Text(route.destination)),
                  DataCell(Text(route.gateway)),
                  DataCell(Text(route.interface)),
                  DataCell(Text('${route.metric}')),
                  DataCell(Text(route.isActive ? l10n.routeActive : l10n.routeInactive)),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
