/// EasyTier CLI RPC 调用封装
///
/// 对应原 Python `Easytier.py` 中的 easytier-cli 调用：
/// - `easytier-cli.exe -p 127.0.0.1:15888 -o json node|peer|route`
/// - 1s 缓存
///
/// 遵循 Flutter 陷阱清单：
/// - 平台通道调用 try/catch
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/utils/logger.dart';

/// EasyTier 节点信息
class EasyTierNodeInfo {
  final String nodeId;
  final String nodeName;
  final String ipv4;
  final String ipv6;
  final double rxBytes;
  final double txBytes;
  final int peerCount;
  final bool isOnline;
  final DateTime lastSeen;

  const EasyTierNodeInfo({
    required this.nodeId,
    this.nodeName = '',
    this.ipv4 = '',
    this.ipv6 = '',
    this.rxBytes = 0,
    this.txBytes = 0,
    this.peerCount = 0,
    this.isOnline = true,
    required this.lastSeen,
  });

  factory EasyTierNodeInfo.fromJson(Map<String, dynamic> json) {
    return EasyTierNodeInfo(
      nodeId: json['node_id']?.toString() ?? '',
      nodeName: json['node_name']?.toString() ?? '',
      ipv4: json['ipv4']?.toString() ?? '',
      ipv6: json['ipv6']?.toString() ?? '',
      rxBytes: (json['rx_bytes'] as num?)?.toDouble() ?? 0,
      txBytes: (json['tx_bytes'] as num?)?.toDouble() ?? 0,
      peerCount: (json['peer_count'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] as bool? ?? true,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'node_name': nodeName,
        'ipv4': ipv4,
        'ipv6': ipv6,
        'rx_bytes': rxBytes,
        'tx_bytes': txBytes,
        'peer_count': peerCount,
        'is_online': isOnline,
        'last_seen': lastSeen.toIso8601String(),
      };

  /// 总流量（MB）
  double get totalTrafficMB => (rxBytes + txBytes) / (1024 * 1024);
}

/// EasyTier 对等节点信息
class EasyTierPeerInfo {
  final String peerId;
  final String peerName;
  final String endpoint;
  final String ipv4;
  final double rxBytes;
  final double txBytes;
  final int latency; // ms
  final bool isConnected;
  final DateTime connectedSince;

  const EasyTierPeerInfo({
    required this.peerId,
    this.peerName = '',
    this.endpoint = '',
    this.ipv4 = '',
    this.rxBytes = 0,
    this.txBytes = 0,
    this.latency = 0,
    this.isConnected = false,
    required this.connectedSince,
  });

  factory EasyTierPeerInfo.fromJson(Map<String, dynamic> json) {
    return EasyTierPeerInfo(
      peerId: json['peer_id']?.toString() ?? '',
      peerName: json['peer_name']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      ipv4: json['ipv4']?.toString() ?? '',
      rxBytes: (json['rx_bytes'] as num?)?.toDouble() ?? 0,
      txBytes: (json['tx_bytes'] as num?)?.toDouble() ?? 0,
      latency: (json['latency'] as num?)?.toInt() ?? 0,
      isConnected: json['is_connected'] as bool? ?? false,
      connectedSince: json['connected_since'] != null
          ? DateTime.tryParse(json['connected_since'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'peer_name': peerName,
        'endpoint': endpoint,
        'ipv4': ipv4,
        'rx_bytes': rxBytes,
        'tx_bytes': txBytes,
        'latency': latency,
        'is_connected': isConnected,
        'connected_since': connectedSince.toIso8601String(),
      };
}

/// EasyTier 路由信息
class EasyTierRouteInfo {
  final String destination;
  final String gateway;
  final String interface;
  final int metric;
  final bool isActive;

  const EasyTierRouteInfo({
    required this.destination,
    this.gateway = '',
    this.interface = '',
    this.metric = 0,
    this.isActive = false,
  });

  factory EasyTierRouteInfo.fromJson(Map<String, dynamic> json) {
    return EasyTierRouteInfo(
      destination: json['destination']?.toString() ?? '',
      gateway: json['gateway']?.toString() ?? '',
      interface: json['interface']?.toString() ?? '',
      metric: (json['metric'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'gateway': gateway,
        'interface': interface,
        'metric': metric,
        'is_active': isActive,
      };
}

/// EasyTier CLI RPC 客户端
///
/// 通过调用 `easytier-cli` 命令行工具获取节点/对等/路由信息。
/// 内置 1s 缓存机制。
class EasyTierCli {
  final String _cliPath;
  final String _rpcAddress;
  final Logger _logger = Logger('EasyTierCli');

  /// 缓存时间（1s）
  static const _cacheDuration = Duration(seconds: 1);

  // 缓存
  List<EasyTierNodeInfo>? _cachedNodes;
  DateTime? _nodesCacheTime;

  List<EasyTierPeerInfo>? _cachedPeers;
  DateTime? _peersCacheTime;

  List<EasyTierRouteInfo>? _cachedRoutes;
  DateTime? _routesCacheTime;

  EasyTierCli({
    required String cliPath,
    String rpcAddress = '127.0.0.1:15888',
  })  : _cliPath = cliPath,
        _rpcAddress = rpcAddress;

  /// 解析 cli 路径（自动检测系统 PATH 中的 easytier-cli）
  static Future<String?> resolveCliPath() async {
    final exeName =
        Platform.isWindows ? 'easytier-cli.exe' : 'easytier-cli';
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [exeName],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        if (await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  // ──────────────────────────── 查询节点 ────────────────────────────

  /// 查询所有节点信息
  ///
  /// 对应 `easytier-cli -p {rpc} -o json node`
  Future<List<EasyTierNodeInfo>> queryNodes({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedNodes != null && _nodesCacheTime != null) {
      if (DateTime.now().difference(_nodesCacheTime!) < _cacheDuration) {
        return _cachedNodes!;
      }
    }

    try {
      final output = await _runCli(['node']);
      final List<dynamic> jsonList = jsonDecode(output) as List<dynamic>;
      _cachedNodes =
          jsonList.map((e) => EasyTierNodeInfo.fromJson(e as Map<String, dynamic>)).toList();
      _nodesCacheTime = DateTime.now();
      return _cachedNodes!;
    } catch (e) {
      _logger.error('查询节点失败', e);
      return _cachedNodes ?? [];
    }
  }

  // ──────────────────────────── 查询对等节点 ────────────────────────────

  /// 查询所有对等节点（peer）信息
  ///
  /// 对应 `easytier-cli -p {rpc} -o json peer`
  Future<List<EasyTierPeerInfo>> queryPeers(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPeers != null && _peersCacheTime != null) {
      if (DateTime.now().difference(_peersCacheTime!) < _cacheDuration) {
        return _cachedPeers!;
      }
    }

    try {
      final output = await _runCli(['peer']);
      final List<dynamic> jsonList = jsonDecode(output) as List<dynamic>;
      _cachedPeers = jsonList
          .map((e) => EasyTierPeerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      _peersCacheTime = DateTime.now();
      return _cachedPeers!;
    } catch (e) {
      _logger.error('查询对等节点失败', e);
      return _cachedPeers ?? [];
    }
  }

  // ──────────────────────────── 查询路由 ────────────────────────────

  /// 查询所有路由信息
  ///
  /// 对应 `easytier-cli -p {rpc} -o json route`
  Future<List<EasyTierRouteInfo>> queryRoutes(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedRoutes != null && _routesCacheTime != null) {
      if (DateTime.now().difference(_routesCacheTime!) < _cacheDuration) {
        return _cachedRoutes!;
      }
    }

    try {
      final output = await _runCli(['route']);
      final List<dynamic> jsonList = jsonDecode(output) as List<dynamic>;
      _cachedRoutes = jsonList
          .map((e) => EasyTierRouteInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      _routesCacheTime = DateTime.now();
      return _cachedRoutes!;
    } catch (e) {
      _logger.error('查询路由失败', e);
      return _cachedRoutes ?? [];
    }
  }

  // ──────────────────────────── 底层调用 ────────────────────────────

  /// 执行 easytier-cli 命令
  Future<String> _runCli(List<String> subcommand) async {
    final args = [
      '-p',
      _rpcAddress,
      '-o',
      'json',
      ...subcommand,
    ];

    _logger.info('easytier-cli ${args.join(' ')}');

    final result = await Process.run(
      _cliPath,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      final err = (result.stderr as String?) ?? 'unknown error';
      throw EasyTierCliException(
        'easytier-cli 失败 (exit=${result.exitCode}): $err',
      );
    }

    return (result.stdout as String?) ?? '[]';
  }

  /// 清除缓存
  void clearCache() {
    _cachedNodes = null;
    _nodesCacheTime = null;
    _cachedPeers = null;
    _peersCacheTime = null;
    _cachedRoutes = null;
    _routesCacheTime = null;
  }
}

/// EasyTier CLI 异常
class EasyTierCliException implements Exception {
  final String message;
  const EasyTierCliException(this.message);

  @override
  String toString() => 'EasyTierCliException: $message';
}
