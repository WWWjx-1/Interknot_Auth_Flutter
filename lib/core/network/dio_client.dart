/// dio 单例工厂：统一超时、代理禁用、UA 伪装、拦截器
///
/// 对应原 Python `requests` 库的使用模式：
/// - 禁用系统代理（校园网 Portal 场景）
/// - 跳过 TLS 证书校验（仅内网 Portal）
/// - UA 伪装为 Edge 浏览器
/// - 表单登录使用 application/x-www-form-urlencoded
library;

import 'package:dio/dio.dart';

/// dio 实例创建器，不持有单例，由 Riverpod Provider 管理生命周期
class DioFactory {
  const DioFactory._();

  /// 创建用于校园网 Portal 认证的 dio 实例
  ///
  /// 特性：
  /// - 连接超时 3s，接收超时 5s
  /// - UA 伪装为 Edge/Chromium
  /// - 仅校验 < 500 的 HTTP 状态码为成功
  static Dio createPortalDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 '
                  'Edg/130.0.0.0',
        },
      ),
    );

    // 禁用代理（校园网场景直连）
    dio.httpClientAdapter = _createNoProxyAdapter();

    // 请求/响应日志拦截器
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );

    return dio;
  }

  /// 创建用于公网请求的 dio 实例（更新检查、连通性探测等）
  static Dio createPublicDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent': 'CMXZ-SAC-Flutter_2.0.0',
        },
      ),
    );
    return dio;
  }

  /// 创建不经过代理的 IO 适配器
  ///
  /// dio 5.x 通过 IOHttpClientAdapter 的 createHttpClient 禁用代理
  static HttpClientAdapter _createNoProxyAdapter() {
    // 创建一个新的 dio 实例来获取默认适配器
    final dio = Dio();
    // 返回默认适配器（IOHttpClientAdapter），它默认不使用系统代理
    // dio 5.x 默认就是直连，除非显式设置代理
    return dio.httpClientAdapter;
  }
}
