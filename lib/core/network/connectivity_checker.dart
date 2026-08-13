/// 公网连通性检测
///
/// 对应原 Python Watch_dog 中的 6 源连通性探测：
/// - msftconnecttest (Microsoft)
/// - gstatic (Google)
/// - google.cn generate_204
/// - apple captive detection
/// - miui generate_204
/// - vivo generate_204
///
/// 任意一个源返回预期状态码即判定为已连通公网
library;

import 'package:dio/dio.dart';

import '../../features/auth/data/esurfing_api.dart';
import '../utils/logger.dart';

/// 连通性检测器
class ConnectivityChecker {
  static final _logger = Logger('ConnectCheck');

  /// 检测任一公网源是否可达
  ///
  /// 返回 true 表示至少一个源返回预期状态码
  static Future<bool> checkAny({
    required Dio dio,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    for (final (url, expectedStatus, method) in EsurfingApi.connectivityCheckUrls) {
      try {
        final response = method == 'HEAD'
            ? await dio.head(
                url,
                options: Options(
                  receiveTimeout: timeout,
                  sendTimeout: timeout,
                  followRedirects: false,
                ),
              )
            : await dio.get(
                url,
                options: Options(
                  receiveTimeout: timeout,
                  sendTimeout: timeout,
                  followRedirects: false,
                ),
              );

        if (response.statusCode == expectedStatus) {
          _logger.debug('连通性检测成功: $url → ${response.statusCode}');
          return true;
        }
      } catch (e) {
        _logger.debug('连通性检测失败: $url → $e');
        // 继续尝试下一个源
      }
    }

    _logger.warn('所有连通性检测源均失败');
    return false;
  }

  /// 检测是否为 Portal 重定向（被校园网劫持到认证页面）
  ///
  /// 返回 true 表示需要认证
  static Future<bool> isCaptivePortal({
    required Dio dio,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final response = await dio.get(
        'http://www.msftconnecttest.com/connecttest.txt',
        options: Options(
          receiveTimeout: timeout,
          sendTimeout: timeout,
          followRedirects: true,
        ),
      );

      // 如果返回内容不是预期的 Microsoft Connect Test
      if (response.statusCode == 200) {
        final body = response.data?.toString() ?? '';
        if (!body.contains('Microsoft Connect Test')) {
          return true; // 被重定向到认证页面
        }
      }
    } catch (_) {}

    return false;
  }

  /// 综合检测：NLM 本地网络 + 公网连通性 + Portal 重定向
  ///
  /// 返回 [ConnectivityStatus] 枚举表示当前网络状态。
  /// 这是 M4 看门狗使用的统一检测入口。
  static Future<ConnectivityStatus> checkFullStatus({
    required Dio dio,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // 1. 先检测公网连通性（6 源）
    final hasInternet = await checkAny(dio: dio, timeout: timeout);

    if (hasInternet) {
      return ConnectivityStatus.connected;
    }

    // 2. 检测是否为 Portal 劫持（需要认证）
    final isPortal = await isCaptivePortal(dio: dio, timeout: timeout);

    if (isPortal) {
      return ConnectivityStatus.portalDetected;
    }

    // 3. 完全不可达
    return ConnectivityStatus.disconnected;
  }
}

/// 连通性综合状态
enum ConnectivityStatus {
  /// 已连接公网
  connected,

  /// 检测到 Portal 认证页面（校园网劫持）
  portalDetected,

  /// 网络完全不可达
  disconnected,
}
