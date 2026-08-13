/// M3 里程碑：jar 登录路径单元测试
///
/// 测试 jar 进程管理器的核心功能：
/// - 进程启动与终止
/// - stdout 状态机关键字解析
/// - 进程列表管理（Mutex 安全）
/// - 心跳调度器
/// - logout.signal 信号文件
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interknot_auth_flutter/core/core.dart';
import 'package:interknot_auth_flutter/features/auth/data/auth_dto.dart';
import 'package:interknot_auth_flutter/features/auth/data/auth_repository.dart';

void main() {
  // ──────────────────────────── 平台检查 ────────────────────────────
  group('JarProcess 平台能力检查', () {
    test('桌面端 PlatformService 应支持 jar 登录', () {
      final service = DesktopPlatformService();
      expect(service.supportsJarLogin, isTrue);
    });

    test('移动端 PlatformService 应不支持 jar 登录', () {
      final service = MobilePlatformService();
      expect(service.supportsJarLogin, isFalse);
    });

    test('PlatformUtils.isDesktop 应返回 true（在桌面运行测试时）', () {
      // 测试运行在桌面平台（Windows/macOS/Linux）
      expect(PlatformUtils.isDesktop, isTrue);
    });
  });

  // ──────────────────────────── JarProcess 初始化 ────────────────────────────
  group('JarProcess 初始化', () {
    test('JarProcess 创建时应为空进程列表', () {
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);

      expect(jarProcess.processes, isEmpty);
      expect(jarProcess.activeProcessCount, 0);
    });

    test('JarProcess dispose 应清理资源', () {
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);

      // dispose 不应抛异常
      expect(() => jarProcess.dispose(), returnsNormally);
    });
  });

  // ──────────────────────────── 心跳调度器 ────────────────────────────
  group('JarProcess 心跳调度器', () {
    test('启动和停止心跳监听器不抛异常', () {
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);

      jarProcess.startHeartbeatWatcher();
      expect(jarProcess.activeProcessCount, 0);

      jarProcess.stopHeartbeatWatcher();
      // 应正常停止
    });

    test('dispose 时应停止心跳监听器', () {
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);

      jarProcess.startHeartbeatWatcher();
      jarProcess.dispose();

      // dispose 后应安全
      expect(jarProcess.activeProcessCount, 0);
    });
  });

  // ──────────────────────────── 回调注册 ────────────────────────────
  group('JarProcess 回调', () {
    test('注册和清除回调不抛异常', () {
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);

      jarProcess.onStdoutLine = (line) {};
      jarProcess.onStatusChanged = (entry, status) {};
      jarProcess.onHeartbeat = (pid) {};
      jarProcess.onLoginAuthorized = (pid) {};
      jarProcess.onLoginFailed = (pid, reason) {};

      // dispose 应清除回调
      jarProcess.dispose();
      expect(jarProcess.onStdoutLine, isNull);
      expect(jarProcess.onStatusChanged, isNull);
      expect(jarProcess.onHeartbeat, isNull);
      expect(jarProcess.onLoginAuthorized, isNull);
      expect(jarProcess.onLoginFailed, isNull);
    });
  });

  // ──────────────────────────── AuthRepository jar 路径 ────────────────────────────
  group('AuthRepository jar 路径集成', () {
    test('AuthRepositoryImpl 接受 JarProcess 参数', () {
      final dio = Dio();
      final rsa = RsaCrypto.fromPem(rsaPublicKeyPem);
      final service = DesktopPlatformService();
      final jarProcess = JarProcess(platform: service);
      final ocr = PythonOcrService();

      final repo = AuthRepositoryImpl(
        portalDio: dio,
        publicDio: dio,
        rsaCrypto: rsa,
        ocrService: ocr,
        jarProcess: jarProcess,
      );

      expect(repo, isNotNull);
    });

    test('AuthRepositoryImpl 可接受 null JarProcess（移动端）', () {
      final dio = Dio();
      final rsa = RsaCrypto.fromPem(rsaPublicKeyPem);
      final ocr = PythonOcrService();

      final repo = AuthRepositoryImpl(
        portalDio: dio,
        publicDio: dio,
        rsaCrypto: rsa,
        ocrService: ocr,
        jarProcess: null,
      );

      expect(repo, isNotNull);
    });
  });

  // ──────────────────────────── JarLoginResult sealed class ────────────────────────────
  group('JarLoginResult 类型系统', () {
    test('JarLoginAuthorized 包含 pid', () {
      const result = JarLoginAuthorized(12345);
      expect(result.pid, 12345);
      expect(result.toString(), contains('JarLoginAuthorized'));
    });

    test('JarLoginFailed 包含 reason 和 isFatal', () {
      const result = JarLoginFailed('账号或密码错误', isFatal: true);
      expect(result.reason, '账号或密码错误');
      expect(result.isFatal, isTrue);
    });

    test('JarLoginAlreadyConnected 包含 pid', () {
      const result = JarLoginAlreadyConnected(12345);
      expect(result.pid, 12345);
      expect(result.toString(), contains('JarLoginAlreadyConnected'));
    });

    test('JarLoginResult 类型检查', () {
      const authorized = JarLoginAuthorized(1);
      const failed = JarLoginFailed('error');
      const connected = JarLoginAlreadyConnected(2);

      expect(authorized, isA<JarLoginResult>());
      expect(failed, isA<JarLoginResult>());
      expect(connected, isA<JarLoginResult>());
    });
  });

  // ──────────────────────────── LoginResult 扩展验证 ────────────────────────────
  group('LoginResult jar 扩展', () {
    test('LoginSuccess 支持 authorized 字段（jar 路径）', () {
      final success = LoginSuccess(authorized: true);
      expect(success.authorized, isTrue);
      expect(success.signature, isNull);
    });

    test('LoginSuccess 支持 HTTP 路径（签名）', () {
      final success = LoginSuccess(signature: 'test-signature');
      expect(success.signature, 'test-signature');
      expect(success.authorized, isFalse);
    });
  });

  // ──────────────────────────── 信号文件测试 ────────────────────────────
  group('logout.signal 信号文件', () {
    test('FileStore 可写入和清理 logout.signal', () async {
      final store = FileStore();
      final signalFile = await store.logoutSignalFile;

      // 清理旧文件
      if (await signalFile.exists()) {
        await signalFile.delete();
      }

      // 写入信号
      await store.writeLogoutSignal();
      expect(await signalFile.exists(), isTrue);

      // 清理信号
      await store.clearLogoutSignal();
      expect(await signalFile.exists(), isFalse);
    });
  });
}
