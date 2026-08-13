/// 认证数据传输对象（DTO）
///
/// 对应原 Python Login_Thread 中构造的登录 JSON payload：
/// ```json
/// {"userName":"...","password":"...","rand":"验证码"}
/// ```
library;

/// 登录请求 payload
class LoginRequest {
  final String userName;
  final String password;
  final String rand;

  const LoginRequest({
    required this.userName,
    required this.password,
    required this.rand,
  });

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'password': password,
        'rand': rand,
      };

  @override
  String toString() => 'LoginRequest(userName=$userName, rand=$rand)';
}

/// 登录结果
sealed class LoginResult {
  const LoginResult();
}

/// 登录成功
class LoginSuccess extends LoginResult {
  /// HTTP 路径的 signature cookie 值
  final String? signature;

  /// 是否已授权（jar 路径）
  final bool authorized;

  const LoginSuccess({this.signature, this.authorized = false});

  @override
  String toString() => 'LoginSuccess(signature=${signature != null ? '***' : 'null'}, authorized=$authorized)';
}

/// 登录失败
class LoginFailed extends LoginResult {
  final String message;
  /// 是否为验证码错误（需要重试）
  final bool isCaptchaError;
  /// 是否为致命错误（不应重试，如密码错误/认证失败/频繁）
  final bool isFatal;

  const LoginFailed({
    required this.message,
    this.isCaptchaError = false,
    this.isFatal = false,
  });

  @override
  String toString() => 'LoginFailed($message, captchaError=$isCaptchaError, fatal=$isFatal)';
}

/// 登录中（用于 UI 状态）
class LoginInProgress extends LoginResult {
  final String step;

  const LoginInProgress(this.step);

  @override
  String toString() => 'LoginInProgress($step)';
}
