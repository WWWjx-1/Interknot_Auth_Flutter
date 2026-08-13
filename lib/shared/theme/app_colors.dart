/// 应用自定义颜色常量
library;

import 'package:flutter/material.dart';

/// 绳网认证品牌色
class AppColors {
  AppColors._();

  /// 主品牌色 - 蓝色系
  static const Color primary = Color(0xFF1A73E8);

  /// 成功状态色
  static const Color success = Color(0xFF34A853);

  /// 警告状态色
  static const Color warning = Color(0xFFFBBC04);

  /// 错误/危险状态色
  static const Color error = Color(0xFFEA4335);

  /// 登录中状态色
  static const Color connecting = Color(0xFF2196F3);

  /// 已连接状态色
  static const Color connected = Color(0xFF4CAF50);

  /// 离线/断开状态色
  static const Color offline = Color(0xFF9E9E9E);
}
