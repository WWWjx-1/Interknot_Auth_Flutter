/// 机器指纹获取
///
/// 对应原 Python `SecurityManager.get_MachineGuid`：
/// - 桌面端：读取 Windows 注册表 `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`
/// - 移动端：使用 device_info_plus 获取设备唯一标识
///
/// MachineGuid 用于派生 AES 密钥（SHA256(MachineGuid + "InterKnot2026")）
/// 这使得 Secret.dat 中的密码绑定到特定机器，跨机无法解密
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 获取机器指纹（MachineGuid 或移动端设备 ID）
///
/// 返回值已去除横线（纯 hex 字符串），与 Python 实现一致
class MachineFingerprint {
  const MachineFingerprint._();

  /// 获取机器唯一标识（去横线的纯 hex 字符串）
  static Future<String> get() async {
    if (Platform.isWindows) {
      return _getWindowsMachineGuid();
    } else {
      return _getMobileDeviceId();
    }
  }

  /// 从 Windows 注册表读取 MachineGuid
  static String _getWindowsMachineGuid() {
    const hkey = HKEY_LOCAL_MACHINE;
    final subKey = 'SOFTWARE\\Microsoft\\Cryptography'.toNativeUtf16();
    final valueName = 'MachineGuid'.toNativeUtf16();

    final hKeyPtr = calloc<HKEY>();
    try {
      final result = RegOpenKeyEx(
        hkey,
        subKey,
        0,
        KEY_READ | KEY_WOW64_64KEY,
        hKeyPtr,
      );

      if (result != ERROR_SUCCESS) {
        throw MachineFingerprintException(
          '无法打开注册表项 (错误码: $result)',
        );
      }

      // 查询值大小
      final dataType = calloc<DWORD>();
      final dataSize = calloc<DWORD>();
      var queryResult = RegQueryValueEx(
        hKeyPtr.value,
        valueName,
        nullptr,
        dataType,
        nullptr,
        dataSize,
      );

      if (queryResult != ERROR_SUCCESS) {
        free(dataType);
        free(dataSize);
        RegCloseKey(hKeyPtr.value);
        throw MachineFingerprintException(
          '无法查询注册表值 (错误码: $queryResult)',
        );
      }

      // 读取值
      final data = calloc<Uint8>(dataSize.value);
      queryResult = RegQueryValueEx(
        hKeyPtr.value,
        valueName,
        nullptr,
        nullptr,
        data.cast(),
        dataSize,
      );

      if (queryResult != ERROR_SUCCESS) {
        free(data);
        free(dataType);
        free(dataSize);
        RegCloseKey(hKeyPtr.value);
        throw MachineFingerprintException(
          '无法读取注册表值 (错误码: $queryResult)',
        );
      }

      // 将 UTF-16 字节转换为字符串
      final guid = data.cast<Utf16>().toDartString(length: dataSize.value ~/ 2);

      free(data);
      free(dataType);
      free(dataSize);
      RegCloseKey(hKeyPtr.value);

      // 去除横线，返回纯 hex（与 Python 一致）
      return guid.replaceAll('-', '');
    } finally {
      free(subKey);
      free(valueName);
      if (hKeyPtr.value != 0) {
        RegCloseKey(hKeyPtr.value);
      }
      free(hKeyPtr);
    }
  }

  /// 移动端设备 ID（Android/iOS）
  static Future<String> _getMobileDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return _hashToGuid(android.id);
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return _hashToGuid(ios.identifierForVendor ?? 'unknown');
      }
    } catch (_) {
      // fallback
    }
    return 'mobile_fallback_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 将任意字符串哈希为类 GUID 格式的 hex
  static String _hashToGuid(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// 派生 AES-256 加密密钥
  ///
  /// SHA256(MachineGuid(去横线) + "InterKnot2026")
  /// 返回 32 字节密钥（Uint8List）
  static Future<Uint8List> deriveEncryptionKey() async {
    final guid = await get();
    final rawKey = '$guid$kSalt';
    return Uint8List.fromList(
      sha256.convert(utf8.encode(rawKey)).bytes,
    );
  }

  /// 密钥派生盐值（与原 Python 一致）
  static const kSalt = 'InterKnot2026';
}

/// 机器指纹获取异常
class MachineFingerprintException implements Exception {
  final String message;
  const MachineFingerprintException(this.message);

  @override
  String toString() => 'MachineFingerprintException: $message';
}
