/// 天翼校园网 Portal 接口常量与连通性探测 URL
///
/// 对应原 Python 中的：
/// - Login_Thread 的 HTTP 路径所有端点
/// - Get_Userip_Thread 的 189.cn 重定向
/// - Watch_dog 的 6 源公网连通性检测
/// - 更新检查接口
library;

/// 天翼 Portal 接口常量
class EsurfingApi {
  EsurfingApi._();

  // ──────────────────────────── 取参（Get_Userip_Thread） ────────────────────────────

  /// 189.cn 探测 URL（通过重定向获取 Portal 参数）
  static const getParamsUrl = 'http://189.cn/';

  /// 取参超时
  static const getParamsTimeoutSeconds = 2;

  // ──────────────────────────── Portal 认证端点 ────────────────────────────

  /// 构造 Portal 首页 URL（用于获取验证码图片 URL）
  ///
  /// [esurfingUrl] 格式如 "10.10.10.10:8080"
  /// [wlanAcIp] wlanacip 参数
  /// [wlanUserIp] wlanuserip 参数
  static String portalIndexUrl({
    required String esurfingUrl,
    required String wlanAcIp,
    required String wlanUserIp,
  }) =>
      'http://$esurfingUrl/qs/index_gz.jsp'
      '?wlanacip=$wlanAcIp'
      '&wlanuserip=$wlanUserIp';

  /// POST 登录端点
  static String loginUrl(String esurfingUrl) =>
      'http://$esurfingUrl/ajax/login';

  /// POST 登出端点
  static String logoutUrl(String esurfingUrl) =>
      'http://$esurfingUrl/ajax/logout';

  // ──────────────────────────── 正则模式 ────────────────────────────

  /// 从 189.cn 最终重定向 URL 中提取 esurfingurl（host:port 部分）
  /// 格式：http://{host:port}/...
  static final esurfingUrlPattern = RegExp(r'http://(.+?)/');

  /// 从 URL 中提取 wlanacip
  static final wlanAcIpPattern = RegExp(r'wlanacip=(.+?)&');

  /// 从 URL 中提取 wlanuserip（取到 URL 末尾）
  static final wlanUserIpPattern = RegExp(r'wlanuserip=(.+)');

  /// 从 Portal 首页 HTML 中提取验证码图片 URL
  /// 匹配 /common/image_code.jsp?time=数字
  static final captchaImageUrlPattern =
      RegExp(r'/common/image_code\.jsp\?time=\d+');

  /// 验证码 OCR 结果清理正则（去除标点/特殊字符）
  static final captchaCleanupPattern = RegExp(
    r'[\s\.:()\[\]{}\-+!@#\$%^&\*_=;,?/]',
  );

  // ──────────────────────────── HTTP 头 ────────────────────────────

  /// Portal 请求 UA（伪装为 Edge 浏览器）
  static const portalUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0';

  /// 更新检查 UA（CMXZ-SAC-Flutter 标识）
  static const updateCheckUserAgent = 'CMXZ-SAC-Flutter_2.0.0';

  // ──────────────────────────── 登录响应关键字 ────────────────────────────

  /// 登录成功 resultCode
  static const loginSuccessCodes = ['0', '13002000'];

  /// 验证码错误提示关键字
  static const captchaErrorKeyword = '验证码错误';

  /// 密码/认证失败关键字（遇到则停止重试）
  static const authFailKeywords = [
    '认证失败',
    '密码错误',
    '账号不存在',
    '频繁',
  ];

  // ──────────────────────────── 重试配置 ────────────────────────────

  /// 验证码错误最大重试次数
  static const maxCaptchaRetries = 5;

  /// 重试间隔（秒）
  static const captchaRetryIntervalSeconds = 3;

  // ──────────────────────────── 连通性检测 ────────────────────────────

  /// 6 源公网连通性探测 URL（格式：url, expectedStatusCode, method）
  static const connectivityCheckUrls = [
    ('http://www.msftconnecttest.com/connecttest.txt', 200, 'HEAD'),
    ('http://connectivitycheck.gstatic.com/generate_204', 204, 'GET'),
    ('http://www.google.cn/generate_204', 204, 'GET'),
    ('http://captive.apple.com/hotspot-detect.html', 200, 'HEAD'),
    ('http://connect.rom.miui.com/generate_204', 204, 'GET'),
    ('http://wifi.vivo.com.cn/generate_204', 204, 'GET'),
  ];

  // ──────────────────────────── 更新检查 ────────────────────────────

  /// cmxz.top 更新检查 URL
  static const updateCheckUrl = 'https://cmxz.top/programs/sac/check.php';

  // ──────────────────────────── EasyTier 默认值 ────────────────────────────

  static const etDefaultSecret = 'Hello_InterKnot';
  static const etVirtualIp = '10.129.114.10';
  static const etPort = 51145;
  static const webuiPort = 50000;
}

/// 取参结果
class EsurfingParams {
  /// Portal 地址（host:port）
  final String esurfingUrl;

  /// AC IP
  final String wlanAcIp;

  /// 用户 IP
  final String wlanUserIp;

  const EsurfingParams({
    required this.esurfingUrl,
    required this.wlanAcIp,
    required this.wlanUserIp,
  });

  /// 创建副本并选择性覆盖字段
  EsurfingParams copyWith({
    String? esurfingUrl,
    String? wlanAcIp,
    String? wlanUserIp,
  }) {
    return EsurfingParams(
      esurfingUrl: esurfingUrl ?? this.esurfingUrl,
      wlanAcIp: wlanAcIp ?? this.wlanAcIp,
      wlanUserIp: wlanUserIp ?? this.wlanUserIp,
    );
  }

  @override
  String toString() =>
      'EsurfingParams(esurfingUrl=$esurfingUrl, '
      'wlanAcIp=$wlanAcIp, wlanUserIp=$wlanUserIp)';
}
