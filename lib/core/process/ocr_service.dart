/// 验证码 OCR 服务抽象与实现
///
/// 对应原 Python 的 ddddocr OCR 流程：
/// 1. 下载验证码图片
/// 2. 预处理：灰度 → 二值化(阈值128) → 中值滤波(size=3)
/// 3. OCR 识别
/// 4. 清理结果（去除标点/特殊字符）
///
/// 桌面端过渡方案：通过 Python 子进程调用 ddddocr
/// 最终方案（M6）：tflite_flutter 加载转换后的模型
/// 移动端：google_mlkit_text_recognition
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// OCR 服务抽象接口
abstract interface class OcrService {
  /// 识别验证码图片
  ///
  /// [imageBytes] 验证码图片的原始字节（PNG/JPEG）
  /// 返回识别出的验证码字符串（已清理标点）
  Future<String> recognize(Uint8List imageBytes);
}

/// 桌面端 OCR 过渡方案：Python 子进程调用 ddddocr
///
/// 通过 Process.run 启动 Python 脚本，将图片通过 stdin 传入，
/// 从 stdout 读取 OCR 结果。
///
/// 最终方案（M6）替换为 tflite_flutter 加载 common_old.tflite
class PythonOcrService implements OcrService {
  final String? _pythonPath;
  final String? _ocrScriptPath;

  /// [pythonPath] Python 解释器路径（默认系统 PATH 中的 python）
  /// [ocrScriptPath] OCR 脚本路径（若不提供，使用内联脚本）
  PythonOcrService({String? pythonPath, String? ocrScriptPath})
      : _pythonPath = pythonPath,
        _ocrScriptPath = ocrScriptPath;

  @override
  Future<String> recognize(Uint8List imageBytes) async {
    final python = _pythonPath ?? 'python';

    try {
      if (_ocrScriptPath != null) {
        return await _runWithScriptFile(python, imageBytes);
      }
      return await _runWithInlineScript(python, imageBytes);
    } catch (e) {
      debugPrint('Python OCR 失败: $e');
      // fallback: 返回空字符串，由调用方处理
      return '';
    }
  }

  /// 通过外部脚本文件运行 OCR
  Future<String> _runWithScriptFile(
      String python, Uint8List imageBytes) async {
    final proc = await Process.start(
      python,
      [_ocrScriptPath!],
    );

    // 将图片字节通过 stdin 传入
    proc.stdin.add(imageBytes);
    await proc.stdin.close();

    final stdoutStr = await utf8.decoder.bind(proc.stdout).join();
    final stderrStr = await utf8.decoder.bind(proc.stderr).join();
    final exitCode = await proc.exitCode;

    if (exitCode != 0) {
      throw OcrException('OCR 脚本失败 (exit=$exitCode): $stderrStr');
    }

    return _cleanResult(stdoutStr.trim());
  }

  /// 通过内联 Python 脚本运行 OCR（推荐过渡方案）
  ///
  /// 内联脚本执行完整的 ddddocr 预处理 + 识别流程
  Future<String> _runWithInlineScript(
      String python, Uint8List imageBytes) async {
    // 内联 Python OCR 脚本：
    // 读取 stdin 的图片字节 → 灰度 → 二值化(128) → 中值滤波(3) → ddddocr
    const script = r'''
import sys
import base64
from PIL import Image
from PIL import ImageFilter
import io

def main():
    # 从 stdin 读取 base64 编码的图片
    data = sys.stdin.buffer.read()
    if not data:
        print('', end='')
        return
    
    try:
        image = Image.open(io.BytesIO(data))
        # 预处理：灰度 → 二值化(阈值128) → 中值滤波(size=3)
        image = image.convert("L")
        image = image.point(lambda p: 255 if p > 128 else 0)
        image = image.filter(ImageFilter.MedianFilter(size=3))
        
        import ddddocr
        ocr = ddddocr.DdddOcr(show_ad=False, ocr=True)
        
        # 将处理后的图片转为字节
        buf = io.BytesIO()
        image.save(buf, format='PNG')
        result = ocr.classification(buf.getvalue())
        
        if result:
            import re
            # 清理标点/特殊字符
            result = re.sub(r'[\s\.:\(\)\[\]\{\}\-\+\!\@\#\$\%\^\&\*\=\;\,\?\/]', '', result)
        
        print(result, end='')
    except Exception as e:
        print(f'OCR_ERROR: {e}', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
''';

    final proc = await Process.start(
      python,
      ['-c', script],
    );

    proc.stdin.add(imageBytes);
    await proc.stdin.close();

    final stdoutStr = await utf8.decoder.bind(proc.stdout).join();
    final stderrStr = await utf8.decoder.bind(proc.stderr).join();
    final exitCode = await proc.exitCode;

    if (exitCode != 0) {
      throw OcrException('OCR 失败 (exit=$exitCode): $stderrStr');
    }

    return _cleanResult(stdoutStr.trim());
  }

  /// 清理 OCR 结果（去除标点/特殊字符）
  static String _cleanResult(String raw) {
    return raw.replaceAll(
      RegExp(r'[\s\.:\(\)\[\]\{\}\-+!@#\$%^&\*_=;,?/]'),
      '',
    );
  }
}

/// OCR 异常
class OcrException implements Exception {
  final String message;
  const OcrException(this.message);

  @override
  String toString() => 'OcrException: $message';
}

/// 移动端 OCR（google_mlkit_text_recognition）
///
/// M6 阶段：使用 google_mlkit_text_recognition 进行验证码识别。
/// 注意：非标准验证码文字的识别率可能较低，需实测评估。
class MlKitOcrService implements OcrService {
  const MlKitOcrService();

  @override
  Future<String> recognize(Uint8List imageBytes) async {
    // google_mlkit_text_recognition 集成（需要移动端设备测试）
    // 参考实现：
    // ```
    // final inputImage = InputImage.fromBytes(
    //   bytes: imageBytes,
    //   metadata: const InputImageMetadata(
    //     size: Size(200, 80),
    //     rotation: InputImageRotation.rotation0deg,
    //     format: InputImageFormat.bgra8888,
    //   ),
    // );
    // final textRecognizer = TextRecognizer();
    // final recognizedText = await textRecognizer.processImage(inputImage);
    // return recognizedText.text;
    // ```
    throw UnimplementedError(
      'MLKit OCR 需要移动端设备测试环境，'
      '桌面端请使用 PythonOcrService 或 TfliteOcrService',
    );
  }
}
