/// 认证数据仓库
///
/// 实现双路径认证（HTTP + jar）的统一接口。
///
/// 对应原 Python：
/// - Login_Thread（HTTP 路径）：取参 → 验证码 → RSA 加密 → POST 登录
/// - Get_Userip_Thread：189.cn 重定向取参
/// - login_Retry_Thread：验证码错误重试（最多 5 次，间隔 3s）
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/core.dart';
import 'auth_dto.dart';
import 'esurfing_api.dart';

/// 认证仓库抽象接口
abstract interface class AuthRepository {
  /// 获取天翼 Portal 参数（esurfingurl, wlanacip, wlanuserip）
  ///
  /// GET http://189.cn/ → 跟随重定向 → 正则解析最终 URL
  Future<EsurfingParams> fetchEsurfingParams();

  /// 执行登录
  ///
  /// 根据用户名和登录模式自动分流：
  /// - IPv4 地址 → 隧道连接（connectEt，M6 实现）
  /// - 非 t 开头且 loginMode==0 且桌面端 → jar 路径（M3 实现）
  /// - 否则 → HTTP 路径
  Future<LoginResult> login({
    required String user,
    required String password,
    required String esurfingUrl,
    required String wlanAcIp,
    required String wlanUserIp,
    required int loginMode,
  });

  /// 登出
  ///
  /// POST /ajax/logout 带 signature cookie
  Future<void> logout({
    required String esurfingUrl,
    required String signature,
  });
}

/// 认证仓库实现
class AuthRepositoryImpl implements AuthRepository {
  final Dio _portalDio;
  final Dio _publicDio;
  final RsaCrypto _rsaCrypto;
  final OcrService _ocrService;
  final JarProcess? _jarProcess;
  final Logger _logger = Logger('AuthRepo');

  AuthRepositoryImpl({
    required Dio portalDio,
    required Dio publicDio,
    required RsaCrypto rsaCrypto,
    required OcrService ocrService,
    JarProcess? jarProcess,
  })  : _portalDio = portalDio,
        _publicDio = publicDio,
        _rsaCrypto = rsaCrypto,
        _ocrService = ocrService,
        _jarProcess = jarProcess;

  // ──────────────────────────── 取参（Get_Userip_Thread） ────────────────────────────

  @override
  Future<EsurfingParams> fetchEsurfingParams() async {
    _logger.info('开始获取 Portal 参数...');

    try {
      // GET http://189.cn/ 并跟随重定向
      // dio 默认 followRedirects=true，通过 Response 的 redirects 获取最终 URL
      final response = await _publicDio.get(
        EsurfingApi.getParamsUrl,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: EsurfingApi.getParamsTimeoutSeconds),
        ),
      );

      // 获取最终重定向后的 URL
      final finalUrl = response.realUri.toString();
      _logger.info('189.cn 最终重定向 URL: $finalUrl');

      return _parseParamsFromUrl(finalUrl);
    } on DioException catch (e) {
      _logger.error('取参失败', e);
      throw AuthException('获取 Portal 参数失败: ${e.message}');
    }
  }

  /// 从 189.cn 重定向 URL 中解析 Portal 参数
  EsurfingParams _parseParamsFromUrl(String url) {
    // 提取 esurfingurl（host:port）
    final esurfingMatch = EsurfingApi.esurfingUrlPattern.firstMatch(url);
    if (esurfingMatch == null) {
      throw AuthException('无法从 URL 中提取 esurfingurl: $url');
    }
    final esurfingUrl = esurfingMatch.group(1)!;

    // 提取 wlanacip
    final acMatch = EsurfingApi.wlanAcIpPattern.firstMatch(url);
    final wlanAcIp = acMatch?.group(1) ?? '';

    // 提取 wlanuserip
    final userMatch = EsurfingApi.wlanUserIpPattern.firstMatch(url);
    final wlanUserIp = userMatch?.group(1) ?? '';

    _logger.info('解析结果: esurfing=$esurfingUrl, ac=$wlanAcIp, userip=$wlanUserIp');

    return EsurfingParams(
      esurfingUrl: esurfingUrl,
      wlanAcIp: wlanAcIp,
      wlanUserIp: wlanUserIp,
    );
  }

  // ──────────────────────────── 登录分流 ────────────────────────────

  @override
  Future<LoginResult> login({
    required String user,
    required String password,
    required String esurfingUrl,
    required String wlanAcIp,
    required String wlanUserIp,
    required int loginMode,
  }) async {
    _logger.info('开始登录: user=$user, mode=$loginMode');

    // 分流 1：IPv4 地址 → 隧道模式（M6 已实现，由 EasyTierController 处理）
    if (IpUtils.isIPv4(user)) {
      _logger.info('检测到 IPv4 地址，进入隧道模式');
      return LoginFailed(
        message: '隧道模式请通过 EasyTier 隧道页面连接，'
            '在隧道页面输入对端 IP 和密钥即可建立连接',
      );
    }

    // 分流 2：HTTP 路径（t 开头 或 loginMode==1）
    if (user.startsWith('t') || loginMode == 1) {
      _logger.info('进入 HTTP 登录路径');
      return _loginHttp(user, password, esurfingUrl, wlanAcIp, wlanUserIp);
    }

    // 分流 3：jar 路径
    if (_jarProcess != null) {
      _logger.info('进入 jar 登录路径');
      return _loginJar(user, password, wlanUserIp, wlanAcIp);
    }

    // 桌面端但 jar 不可用（jre/login.jar 缺失）
    _logger.error('jar 登录不可用（缺少 jre 或 login.jar）');
    return LoginFailed(
      message: 'jar 登录不可用，请确保已复制 jre 和 login.jar 到 assets/bin/，'
          '或使用 t 模式登录',
      isFatal: true,
    );
  }

  // ──────────────────────────── jar 登录路径 ────────────────────────────

  /// jar 路径登录（桌面端，通过外部 java 子进程）
  ///
  /// 对应原 Python `Jar_Thread.run()`：
  /// 1. 启动 java -jar login.jar -u {user} -p {pwd} -t {userIp} -a {acIp}
  /// 2. stdout 行解析状态机
  /// 3. 关键字：authorized → 成功 / KeepUrl empty → 密码错误
  /// 4. 成功后 jar 内部自动心跳（~480s）
  Future<LoginResult> _loginJar(
    String user,
    String password,
    String userIp,
    String acIp,
  ) async {
    _logger.info('jar 登录: user=$user, ip=$userIp, ac=$acIp');

    try {
      final result = await _jarProcess!.login(
        username: user,
        password: password,
        userIp: userIp,
        acIp: acIp,
      );

      switch (result) {
        case JarLoginAuthorized(:final pid):
          _logger.info('jar 登录成功! pid=$pid');
          // jar 路径不返回 signature（心跳保活代替）
          return LoginSuccess(authorized: true);

        case JarLoginAlreadyConnected(:final pid):
          _logger.info('jar 进程 $pid: 设备已连接互联网，无需重复登录');
          return LoginFailed(
            message: '当前设备已连接互联网，无需再次登录',
            isFatal: true,
          );

        case JarLoginFailed(:final reason, :final isFatal):
          _logger.error('jar 登录失败: $reason');
          // 密码/账号错误 → 致命错误，不重试
          if (reason.contains('账号或密码错误') || reason.contains('密码错误')) {
            return LoginFailed(message: reason, isFatal: true);
          }
          return LoginFailed(message: reason, isFatal: isFatal);
      }
    } catch (e, s) {
      _logger.error('jar 登录异常', e, s);
      return LoginFailed(message: 'jar 登录异常: $e', isFatal: true);
    }
  }

  // ──────────────────────────── HTTP 登录路径 ────────────────────────────

  /// HTTP 路径完整登录流程（含验证码错误重试）
  Future<LoginResult> _loginHttp(
    String user,
    String password,
    String esurfingUrl,
    String wlanAcIp,
    String wlanUserIp,
  ) async {
    for (var attempt = 1; attempt <= EsurfingApi.maxCaptchaRetries; attempt++) {
      _logger.info('HTTP 登录尝试 $attempt/${EsurfingApi.maxCaptchaRetries}');

      try {
        final result = await _attemptHttpLogin(
          user,
          password,
          esurfingUrl,
          wlanAcIp,
          wlanUserIp,
          attempt,
        );

        // 登录成功或致命错误 → 直接返回
        if (result is LoginSuccess) return result;
        if (result is LoginFailed && result.isFatal) return result;

        // 验证码错误 → 等待后重试
        if (result is LoginFailed && result.isCaptchaError) {
          if (attempt < EsurfingApi.maxCaptchaRetries) {
            _logger.info(
              '验证码错误，${EsurfingApi.captchaRetryIntervalSeconds}s 后重试...',
            );
            await Future.delayed(
              const Duration(seconds: EsurfingApi.captchaRetryIntervalSeconds),
            );
            continue;
          }
          return LoginFailed(
            message: '验证码错误已达最大重试次数(${EsurfingApi.maxCaptchaRetries})',
            isCaptchaError: true,
          );
        }

        // 其他错误 → 返回
        return result;
      } catch (e, s) {
        _logger.error('HTTP 登录异常', e, s);
        return LoginFailed(message: '登录异常: $e');
      }
    }

    return LoginFailed(
      message: '验证码错误已达最大重试次数(${EsurfingApi.maxCaptchaRetries})',
      isCaptchaError: true,
    );
  }

  /// 单次 HTTP 登录尝试
  Future<LoginResult> _attemptHttpLogin(
    String user,
    String password,
    String esurfingUrl,
    String wlanAcIp,
    String wlanUserIp,
    int attempt,
  ) async {
    // Step 1: 获取验证码图片 URL
    _logger.info('Step 1: 获取 Portal 首页...');
    final portalUrl = EsurfingApi.portalIndexUrl(
      esurfingUrl: esurfingUrl,
      wlanAcIp: wlanAcIp,
      wlanUserIp: wlanUserIp,
    );

    final portalResponse = await _portalDio.get(
      portalUrl,
      options: Options(
        headers: {
          'Origin': 'http://$esurfingUrl',
          'User-Agent': EsurfingApi.portalUserAgent,
        },
      ),
    );

    // Step 2: 从 HTML 中提取验证码图片 URL
    _logger.info('Step 2: 提取验证码 URL...');
    final htmlBody = portalResponse.data?.toString() ?? '';
    final captchaMatch =
        EsurfingApi.captchaImageUrlPattern.firstMatch(htmlBody);
    if (captchaMatch == null) {
      _logger.error('HTML 中未找到验证码 URL');
      return LoginFailed(message: '未找到验证码图片 URL', isFatal: true);
    }

    final captchaImageUrl = 'http://$esurfingUrl${captchaMatch.group(0)}';
    _logger.info('验证码 URL: $captchaImageUrl');

    // Step 3: 下载验证码图片
    _logger.info('Step 3: 下载验证码图片...');
    final captchaResponse = await _portalDio.get(
      captchaImageUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    final captchaBytes = captchaResponse.data;
    if (captchaBytes == null || (captchaBytes is List<int> && captchaBytes.isEmpty)) {
      return LoginFailed(message: '验证码图片为空', isFatal: true);
    }

    // Step 4: OCR 识别验证码
    _logger.info('Step 4: OCR 识别验证码...');
    final captchaUint8List = captchaBytes is Uint8List
        ? captchaBytes
        : Uint8List.fromList(captchaBytes as List<int>);
    final captchaCode = await _ocrService.recognize(captchaUint8List);
    _logger.info('OCR 结果: "$captchaCode"');

    if (captchaCode.isEmpty) {
      return LoginFailed(message: '验证码识别失败', isCaptchaError: true);
    }

    // Step 5: RSA 加密 loginKey
    _logger.info('Step 5: RSA 加密 loginKey...');
    final loginPayload = LoginRequest(
      userName: user,
      password: password,
      rand: captchaCode,
    );
    final payloadJson = jsonEncode(loginPayload.toJson());
    _logger.info('Payload: $payloadJson');

    final loginKey = _rsaCrypto.encryptHex(payloadJson);
    _logger.info('loginKey (hex): ${loginKey.substring(0, 20)}...');

    // Step 6: POST /ajax/login
    _logger.info('Step 6: POST 登录...');
    final loginResponse = await _portalDio.post(
      EsurfingApi.loginUrl(esurfingUrl),
      data: {
        'loginKey': loginKey,
        'wlanuserip': wlanUserIp,
        'wlanacip': wlanAcIp,
      },
      options: Options(
        headers: {
          'Origin': 'http://$esurfingUrl',
          'User-Agent': EsurfingApi.portalUserAgent,
          'Content-Type': Headers.formUrlEncodedContentType,
        },
      ),
    );

    // Step 7: 解析登录结果
    _logger.info('Step 7: 解析登录结果...');
    final responseData = loginResponse.data;
    if (responseData is! Map<String, dynamic>) {
      return LoginFailed(message: '服务器返回格式异常');
    }

    final resultCode = responseData['resultCode']?.toString() ?? '';
    final resultInfo = responseData['resultInfo']?.toString() ?? '';

    _logger.info('resultCode=$resultCode, resultInfo=$resultInfo');

    // 登录成功
    if (EsurfingApi.loginSuccessCodes.contains(resultCode)) {
      // 从 Set-Cookie 头提取 signature
      final signature = _extractSignature(loginResponse);
      _logger.info('登录成功! signature=${signature != null ? "***" : "null"}');
      return LoginSuccess(signature: signature);
    }

    // 验证码错误
    if (resultInfo.contains(EsurfingApi.captchaErrorKeyword)) {
      _logger.warn('验证码错误: $resultInfo');
      return LoginFailed(
        message: resultInfo,
        isCaptchaError: true,
      );
    }

    // 致命错误（密码错误/认证失败/频繁）
    for (final keyword in EsurfingApi.authFailKeywords) {
      if (resultInfo.contains(keyword)) {
        _logger.error('认证失败: $resultInfo');
        return LoginFailed(message: resultInfo, isFatal: true);
      }
    }

    // 其他错误
    return LoginFailed(message: resultInfo.isNotEmpty ? resultInfo : '登录失败($resultCode)');
  }

  /// 从响应头提取 signature cookie
  String? _extractSignature(Response response) {
    final cookies = response.headers.map['set-cookie'];
    if (cookies == null) return null;

    for (final cookie in cookies) {
      if (cookie.contains('signature')) {
        // 格式: signature=xxx; path=/; ...
        final match = RegExp(r'signature=([^;]+)').firstMatch(cookie);
        return match?.group(1);
      }
    }
    return null;
  }

  // ──────────────────────────── 登出 ────────────────────────────

  @override
  Future<void> logout({
    required String esurfingUrl,
    required String signature,
  }) async {
    _logger.info('开始登出...');

    try {
      await _portalDio.post(
        EsurfingApi.logoutUrl(esurfingUrl),
        options: Options(
          headers: {
            'Cookie': 'signature=$signature',
            'Origin': 'http://$esurfingUrl',
            'User-Agent': EsurfingApi.portalUserAgent,
          },
        ),
      );
      _logger.info('登出成功');
    } on DioException catch (e) {
      _logger.error('登出失败', e);
      throw AuthException('登出失败: ${e.message}');
    }
  }
}

/// 认证异常
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
