/// 日志控制台 Widget
///
/// 对应原 Python `listWidget`，显示应用运行日志。
///
/// 特性：
/// - 最多保留 1000 行日志
/// - 自动滚动到底部
/// - 按日志级别着色（DEBUG 灰 / INFO 蓝 / WARN 橙 / ERROR 红）
/// - 等宽字体
/// - 可清除、可复制全部日志
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/logger.dart';
import '../../l10n/app_localizations.dart';

// ──────────────────────────── 日志条目 ────────────────────────────

/// 日志条目数据
class LogEntry {
  /// 时间戳
  final DateTime timestamp;

  /// 日志级别
  final LogLevel level;

  /// 来源模块标签
  final String tag;

  /// 日志消息
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  /// 格式化时间
  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ──────────────────────────── 日志缓冲 ────────────────────────────

/// 全局日志缓冲区
///
/// 通过 [Logger.onLog] 回调自动收集日志。
class LogBuffer {
  static final List<LogEntry> _entries = [];
  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);

  /// 最大保留条目数
  static const maxEntries = 1000;

  /// 添加日志条目
  static void add(LogEntry entry) {
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    _notifier.value = _entries.length;
  }

  /// 清除所有日志
  static void clear() {
    _entries.clear();
    _notifier.value = 0;
  }

  /// 获取所有日志条目（只读）
  static List<LogEntry> get entries => List.unmodifiable(_entries);

  /// 条目数量变化通知
  static ValueNotifier<int> get notifier => _notifier;

  /// 获取全部日志文本（用于复制）
  static String getAllText() {
    return _entries.map((e) {
      final levelStr = e.level.prefix;
      return '${e.formattedTime} $levelStr [${e.tag}] ${e.message}';
    }).join('\n');
  }
}

// ──────────────────────────── 日志控制台 Widget ────────────────────────────

/// 日志控制台 Widget
///
/// 用法：
/// ```dart
/// LogConsole()
/// ```
class LogConsole extends StatefulWidget {
  /// 最大高度（null = 自适应）
  final double? maxHeight;

  /// 是否紧凑模式
  final bool compact;

  const LogConsole({
    super.key,
    this.maxHeight,
    this.compact = false,
  });

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    LogBuffer.notifier.addListener(_onLogChanged);

    // 监听用户手动滚动
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // 如果用户在底部附近（100px 内），启用自动滚动
      _autoScroll = (maxScroll - currentScroll) < 100;
    });
  }

  @override
  void dispose() {
    LogBuffer.notifier.removeListener(_onLogChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogChanged() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_autoScroll && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题栏
        _buildHeader(context, colorScheme),
        // 日志列表
        Flexible(
          child: Container(
            constraints: widget.maxHeight != null
                ? BoxConstraints(maxHeight: widget.maxHeight!)
                : null,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(128),
              ),
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: LogBuffer.notifier,
              builder: (context, count, _) {
                final entries = LogBuffer.entries;
                if (entries.isEmpty) {
                  final l10n = AppLocalizations.of(context);
                  return Center(
                    child: Text(
                      l10n.noLogs,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withAlpha(128),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: entries.length,
                  itemExtent: widget.compact ? 20 : 24,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildLogRow(entry, theme, colorScheme);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final count = LogBuffer.entries.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.terminal,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.runningLogs,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha(160),
              ),
            ),
          ],
          const Spacer(),
          // 复制按钮
          _MiniIconButton(
            icon: Icons.copy,
            tooltip: l10n.copyAllLogs,
            onPressed: () {
              final text = LogBuffer.getAllText();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.logsCopied),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // 清除按钮
          _MiniIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: l10n.clearLogs,
            onPressed: () {
              LogBuffer.clear();
            },
          ),
        ],
      ),
    );
  }

  /// 构建单行日志
  Widget _buildLogRow(
    LogEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final levelColor = switch (entry.level) {
      LogLevel.debug => Colors.grey,
      LogLevel.info => Colors.blue,
      LogLevel.warn => Colors.orange,
      LogLevel.error => Colors.red,
    };

    final fontSize = widget.compact ? 10.0 : 11.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间戳
        SizedBox(
          width: widget.compact ? 52 : 60,
          child: Text(
            entry.formattedTime,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              color: colorScheme.onSurfaceVariant.withAlpha(160),
            ),
          ),
        ),
        // 级别标签
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 2 : 4,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: levelColor.withAlpha(30),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            entry.level.prefix,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize - 1,
              color: levelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 标签
        Text(
          '[${entry.tag}]',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            color: colorScheme.primary.withAlpha(200),
          ),
        ),
        const SizedBox(width: 4),
        // 消息
        Expanded(
          child: Text(
            entry.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────── 小型图标按钮 ────────────────────────────

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
