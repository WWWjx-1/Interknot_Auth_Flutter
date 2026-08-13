/// AES-GCM 加解密工具
///
/// 对应原 Python `SecurityManager` 中的 AES-GCM 加解密：
/// - 密钥：SHA256(MachineGuid(去横线) + "InterKnot2026")
/// - 模式：AES-GCM，随机 nonce
/// - 输出格式：base64(nonce[16] + tag[16] + ciphertext)
///
/// 主要用途：
/// 1. 数据迁移工具解密旧 Secret.dat 中的密码
/// 2. 作为 flutter_secure_storage 不可用时的 fallback 方案
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-GCM 加解密器
class AesGcmCrypto {
  final Uint8List _key;

  /// 用 32 字节 AES-256 密钥构造
  AesGcmCrypto(this._key) {
    if (_key.length != 32) {
      throw ArgumentError('AES-256 密钥必须为 32 字节，实际为 ${_key.length}');
    }
  }

  /// 加密明文，返回 base64 字符串
  ///
  /// 格式：nonce[16] + tag[16] + ciphertext
  String encrypt(String plaintext) {
    final nonce = _generateNonce();
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)),
      );

    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final out = Uint8List(cipher.getOutputSize(plainBytes.length));
    final len = cipher.processBytes(plainBytes, 0, plainBytes.length, out, 0);
    cipher.doFinal(out, len);

    // GCMBlockCipher 加密输出：ciphertext[0..plainLen) + tag[plainLen..plainLen+16)
    // plainLen = plainBytes.length
    final plainLen = plainBytes.length;
    final ct = Uint8List.fromList(out.sublist(0, plainLen));
    final tag = Uint8List.fromList(out.sublist(plainLen, plainLen + 16));

    // 拼接：nonce[16] + tag[16] + ciphertext
    final result = Uint8List(16 + 16 + ct.length);
    result.setAll(0, nonce);
    result.setAll(16, tag);
    result.setAll(32, ct);

    return base64.encode(result);
  }

  /// 解密 base64 编码的密文
  ///
  /// [encryptedBase64] 格式：base64(nonce[16] + tag[16] + ciphertext)
  String decrypt(String encryptedBase64) {
    final raw = base64.decode(encryptedBase64);

    if (raw.length < 32) {
      throw ArgumentError('密文太短');
    }
    final nonce = Uint8List.fromList(raw.sublist(0, 16));
    final tag = Uint8List.fromList(raw.sublist(16, 32));
    final ct = Uint8List.fromList(raw.sublist(32));

    // GCM 解密输入：ciphertext + tag
    final input = Uint8List(ct.length + 16);
    input.setAll(0, ct);
    input.setAll(ct.length, tag);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)),
      );

    final out = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, out, 0);
    cipher.doFinal(out, len);

    // 解密输出：plaintext[0..ct.length)
    return utf8.decode(out.sublist(0, ct.length));
  }

  Uint8List _generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }
}
