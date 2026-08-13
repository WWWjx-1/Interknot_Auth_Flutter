/// 版本号工具
///
/// 用于与 cmxz.top 更新检查接口返回的版本号进行比较。
library;

/// 版本号比较工具
class VersionUtils {
  const VersionUtils._();

  /// 比较两个版本号字符串
  ///
  /// 返回：
  /// - 正数：v1 > v2
  /// - 0：v1 == v2
  /// - 负数：v1 < v2
  static int compare(String v1, String v2) {
    final parts1 = _parseParts(v1);
    final parts2 = _parseParts(v2);
    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (var i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  /// 解析版本号字符串为整数列表
  static List<int> _parseParts(String version) {
    return version
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
  }
}
