/// 平台能力抽象接口
///
/// 定义所有需要平台分支的能力，桌面端和移动端各自实现。
/// 通过 Riverpod Provider 注入，调用方不感知平台差异。
///
/// 对应原 Python 中通过 `sys.platform` 分支处理 Windows/Mac 的逻辑。
library;

import 'dart:io';

/// 平台能力抽象接口
abstract interface class PlatformService {
  /// 是否支持 jar 登录（桌面端 true，移动端 false）
  bool get supportsJarLogin;

  /// 是否支持 EasyTier 组网
  bool get supportsEasyTier;

  /// 是否支持系统托盘
  bool get supportsSystemTray;

  /// 是否支持开机自启
  bool get supportsAutoStart;

  /// 解析 assets/bin 下的资源文件路径
  ///
  /// 桌面端返回文件系统绝对路径，移动端返回 bundle 内路径
  Future<String> resolveAssetPath(String relativePath);

  /// 查找 Java 可执行文件路径
  ///
  /// 桌面端：返回捆绑 jre/bin/java.exe
  /// 移动端：返回 null（不支持）
  Future<String?> resolveJavaPath();

  /// 获取应用数据目录
  Future<String> getAppDataDir();

  /// 获取系统临时目录
  Future<String> getTempDir();

  /// 添加路由（需要管理员权限）
  ///
  /// [destination] 目标网段（如 '0.0.0.0'）
  /// [gateway] 网关（如 '10.129.114.10'）
  Future<void> addRoute(String destination, String gateway);

  /// 删除路由
  Future<void> deleteRoute(String destination);

  /// 检查是否有管理员权限
  Future<bool> hasAdminPrivilege();

  /// 平台名称（调试用）
  String get platformName;
}

/// 平台工具函数
class PlatformUtils {
  const PlatformUtils._();

  /// 当前是否为桌面平台
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 当前是否为移动平台
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
