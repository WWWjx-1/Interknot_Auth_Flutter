/// 路由表定义（go_router）
///
/// 对应原项目所有页面路由。
/// M6 阶段：EasyTier Dashboard/共享/隧道页面已实现。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show appNavigatorKey;
import '../../features/auth/presentation/login_page.dart';
import '../../features/easytier/presentation/dashboard_page.dart';
import '../../features/easytier/presentation/share_page.dart';
import '../../features/easytier/presentation/tunnel_page.dart';
import '../../features/multilogin/presentation/multilogin_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/params_page.dart';

/// 路由 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LoginPage(),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardPage(),
            ),
          ),
          GoRoute(
            path: '/multilogin',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MultiloginPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
          GoRoute(
            path: '/params',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ParamsPage(),
            ),
          ),
          GoRoute(
            path: '/share',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SharePage(),
            ),
          ),
          GoRoute(
            path: '/tunnel',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TunnelPage(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// 主壳容器：提供统一的导航框架（侧栏/底部导航等，M0 暂为简单 Scaffold）
class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
    );
  }
}
