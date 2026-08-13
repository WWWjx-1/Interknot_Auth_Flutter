/// IP 地址工具函数
///
/// 对应原 Python 中的 IP 格式检测逻辑：
/// - IPv4 地址正则匹配
/// - 用于判断用户名是否为 IP（隧道模式 vs 认证模式）
library;

/// IP 地址工具
class IpUtils {
  const IpUtils._();

  /// 简单 IPv4 格式检测（xxx.xxx.xxx.xxx）
  static final _ipv4RegExp = RegExp(
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
  );

  /// 判断字符串是否为 IPv4 地址格式
  static bool isIPv4(String value) {
    if (!_ipv4RegExp.hasMatch(value)) return false;
    // 验证每段值在 0-255 范围内
    final parts = value.split('.').map(int.parse).toList();
    return parts.every((p) => p >= 0 && p <= 255);
  }

  /// 判断字符串是否为 IPv6 地址格式（简单检测）
  static bool isIPv6(String value) {
    return value.contains(':') && value.split(':').length >= 2;
  }
}
