/// 移动端平台服务实现（Android/iOS 功能子集）
///
/// 移动端不支持：
/// - jar 登录（无 JVM）
/// - EasyTier 组网（无 easytier-core）
/// - 系统托盘、开机自启
/// - 路由管理
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'platform_service.dart';

/// 移动端平台服务实现（功能子集）
class MobilePlatformService implements PlatformService {
  @override
  bool get supportsJarLogin => false;

  @override
  bool get supportsEasyTier => false;

  @override
  bool get supportsSystemTray => false;

  @override
  bool get supportsAutoStart => false;

  @override
  String get platformName => Platform.operatingSystem;

  @override
  Future<String> resolveAssetPath(String relativePath) async {
    // 移动端资源在 bundle 内，返回相对路径供 rootBundle 使用
    return relativePath;
  }

  @override
  Future<String?> resolveJavaPath() async {
    // 移动端不支持 JVM
    return null;
  }

  @override
  Future<String> getAppDataDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  Future<String> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<void> addRoute(String destination, String gateway) async {
    throw UnsupportedError('移动端不支持路由管理');
  }

  @override
  Future<void> deleteRoute(String destination) async {
    throw UnsupportedError('移动端不支持路由管理');
  }

  @override
  Future<bool> hasAdminPrivilege() async {
    // 移动端不适用
    return true;
  }
}
