/// 认证领域状态模型
///
/// 对应原 Python 中的登录态枚举：
/// - IDLE: 未登录
/// - LOGGING_IN: 登录中
/// - CONNECTED: 已连接
/// - DISCONNECTED: 断线
/// - ERROR: 错误
library;

/// 认证状态枚举
enum AuthStatus {
  /// 空闲（未登录）
  idle,

  /// 正在获取参数
  fetchingParams,

  /// 正在登录
  loggingIn,

  /// 已连接（已认证）
  connected,

  /// 已断线
  disconnected,

  /// 错误
  error,
}

/// 登录模式
enum LoginMode {
  /// jar 路径（桌面端默认）
  jar,

  /// HTTP 路径（t 模式 / 教师账号）
  http,

  /// 隧道模式（用户名是 IP）
  tunnel,
}
