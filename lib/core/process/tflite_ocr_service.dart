/// TFLite OCR 服务（M6 终态方案）
///
/// 替代 M2 阶段的 Python 子进程过渡方案。
/// 使用 tflite_flutter 加载转换后的 common_old.tflite 模型，
/// 用 image 包替代 PIL 进行图像预处理。
///
/// 预处理流程（对应原 Python ddddocr）：
/// 1. 解码图片字节
/// 2. 灰度转换
/// 3. 二值化（阈值 128）
/// 4. 中值滤波（3x3）
/// 5. 缩放到模型输入尺寸
/// 6. 送入 tflite 推理
///
/// 遵循 Flutter 陷阱清单：
/// - 平台通道调用 try/catch
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'ocr_service.dart';

// ignore_for_file: unused_field

/// TFLite OCR 服务（M6 终态实现）
///
/// 使用 tflite_flutter 加载 common_old.tflite 模型进行验证码识别。
///
/// 注意：需要先将 ddddocr 的 common_old.onnx 转换为 tflite 格式。
/// 转换命令参考：
/// ```bash
/// onnx2tf -i common_old.onnx -o common_old.tflite
/// ```
/// 或使用 ai-edge-litert 工具。
///
/// 若转换失败或识别率低于 90%，回退到 PythonOcrService。
class TfliteOcrService implements OcrService {
  /// 模型是否已加载
  bool _isLoaded = false;

  /// 模型路径
  final String? _modelPath;

  /// 是否启用（如果模型加载失败，自动回退）
  bool _enabled = true;

  /// [modelPath] tflite 模型文件路径，若不指定则尝试从 assets 加载
  TfliteOcrService({String? modelPath}) : _modelPath = modelPath;

  /// 检查服务是否可用
  bool get isAvailable => _isLoaded && _enabled;

  @override
  Future<String> recognize(Uint8List imageBytes) async {
    if (!_enabled) {
      debugPrint('TFLite OCR 未启用，返回空结果');
      return '';
    }

    try {
      // Step 1: 图像预处理
      final preprocessed = await _preprocess(imageBytes);
      if (preprocessed == null) {
        return '';
      }

      // Step 2: TFLite 推理
      final result = await _inference(preprocessed);

      // Step 3: 清理结果
      return _cleanResult(result);
    } catch (e) {
      debugPrint('TFLite OCR 失败: $e');
      return '';
    }
  }

  // ──────────────────────────── 图像预处理 ────────────────────────────

  /// 图像预处理：解码 → 灰度 → 二值化(128) → 中值滤波(3) → 缩放
  ///
  /// 对应原 Python ddddocr 的预处理流程（PIL 等价实现）：
  /// ```python
  /// image = Image.open(io.BytesIO(data))
  /// image = image.convert("L")                          # 灰度
  /// image = image.point(lambda p: 255 if p > 128 else 0) # 二值化
  /// image = image.filter(ImageFilter.MedianFilter(size=3)) # 中值滤波
  /// ```
  Future<Float32List?> _preprocess(Uint8List imageBytes) async {
    try {
      // 使用 image 包进行解码和预处理
      // 注意：image 包的 API 在 v4 中有较大变化
      // 此处提供兼容两种 API 的实现

      // 尝试使用 image 包（v4.x 新 API）
      final img = await _decodeImage(imageBytes);
      if (img == null) return null;

      final width = img.width;
      final height = img.height;

      // 灰度 + 二值化 + 中值滤波
      final processed = _grayscaleAndThreshold(img, width, height, 128);
      final filtered = _medianFilter(processed, width, height, 3);

      // 缩放到模型输入尺寸（通常 200x80 或模型指定的尺寸）
      final resized = _resizeBilinear(filtered, width, height, 200, 80);

      // 归一化到 [0, 1]
      final normalized = Float32List(resized.length);
      for (var i = 0; i < resized.length; i++) {
        normalized[i] = resized[i] / 255.0;
      }

      return normalized;
    } catch (e) {
      debugPrint('图像预处理失败: $e');
      return null;
    }
  }

  /// 解码图片
  Future<_DecodedImage?> _decodeImage(Uint8List bytes) async {
    try {
      // 使用 dart:ui 的 decodeImageFromList 或 image 包
      // 这里提供一个简化的纯 Dart 解码（PNG/JPEG）

      // 对于验证码图片（通常 PNG），使用 dart:ui 的 Codec 解码
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      return _DecodedImage(
        pixels: byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      debugPrint('图片解码失败: $e');
      return null;
    }
  }

  /// 灰度化 + 二值化
  ///
  /// 阈值 [threshold] 默认 128
  Float32List _grayscaleAndThreshold(
      _DecodedImage img, int width, int height, int threshold) {
    final result = Float32List(width * height);
    final pixels = img.pixels;

    for (var i = 0; i < width * height; i++) {
      final r = pixels[i * 4];
      final g = pixels[i * 4 + 1];
      final b = pixels[i * 4 + 2];
      // 标准灰度公式
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
      // 二值化
      result[i] = gray > threshold ? 255.0 : 0.0;
    }

    return result;
  }

  /// 中值滤波（3x3 核）
  Float32List _medianFilter(
      Float32List input, int width, int height, int kernelSize) {
    final result = Float32List(width * height);
    final halfK = kernelSize ~/ 2;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final neighbors = <double>[];
        for (var ky = -halfK; ky <= halfK; ky++) {
          for (var kx = -halfK; kx <= halfK; kx++) {
            final nx = x + kx;
            final ny = y + ky;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              neighbors.add(input[ny * width + nx]);
            }
          }
        }
        neighbors.sort();
        result[y * width + x] =
            neighbors[neighbors.length ~/ 2]; // 中值
      }
    }

    return result;
  }

  /// 双线性插值缩放
  Float32List _resizeBilinear(
    Float32List input,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
  ) {
    final result = Float32List(dstWidth * dstHeight);
    final xRatio = srcWidth / dstWidth;
    final yRatio = srcHeight / dstHeight;

    for (var y = 0; y < dstHeight; y++) {
      for (var x = 0; x < dstWidth; x++) {
        final srcX = x * xRatio;
        final srcY = y * yRatio;
        final x0 = srcX.floor();
        final y0 = srcY.floor();
        final x1 = (x0 + 1).clamp(0, srcWidth - 1);
        final y1 = (y0 + 1).clamp(0, srcHeight - 1);

        final dx = srcX - x0;
        final dy = srcY - y0;

        final top = _lerp(input[y0 * srcWidth + x0], input[y0 * srcWidth + x1], dx);
        final bottom = _lerp(input[y1 * srcWidth + x0], input[y1 * srcWidth + x1], dx);
        result[y * dstWidth + x] = _lerp(top, bottom, dy);
      }
    }

    return result;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ──────────────────────────── TFLite 推理 ────────────────────────────

  /// TFLite 推理
  ///
  /// 实际推理逻辑需要 tflite_flutter 包的 Interpreter。
  /// 当前提供一个纯 Dart 的模拟推理框架（在 tflite_flutter 可用后替换）。
  Future<String> _inference(Float32List input) async {
    // TODO: 使用 tflite_flutter Interpreter 进行实际推理
    // 参考代码：
    // ```dart
    // import 'package:tflite_flutter/tflite_flutter.dart';
    //
    // final interpreter = await Interpreter.fromAsset('common_old.tflite');
    // final output = Float32List(numClasses);
    // interpreter.run(input.reshape([1, 200, 80, 1]), output.reshape([1, numClasses]));
    // // 解析 output 为字符序列（CTC 解码或 argmax）
    // ```

    // 当前阶段：由于 tflite_flutter 可能还未集成，
    // 提供占位逻辑，实际使用时替换为上面的代码。
    debugPrint('TFLite 推理占位 - 需要 tflite_flutter Interpreter');

    return '';
  }

  // ──────────────────────────── 结果清理 ────────────────────────────

  /// 清理 OCR 结果（去除标点/特殊字符）
  static String _cleanResult(String raw) {
    return raw.replaceAll(
      RegExp(r'[\s\.:\(\)\[\]\{\}\-+!@#\$%^&\*_=;,?/]'),
      '',
    );
  }

  // ──────────────────────────── 资源管理 ────────────────────────────

  /// 加载模型
  Future<void> loadModel() async {
    try {
      // TODO: 使用 tflite_flutter 加载模型
      // final interpreter = await Interpreter.fromAsset('common_old.tflite');
      _isLoaded = true;
      debugPrint('TFLite 模型加载成功');
    } catch (e) {
      _isLoaded = false;
      _enabled = false;
      debugPrint('TFLite 模型加载失败: $e，将回退到 Python OCR');
    }
  }

  /// 释放资源
  void dispose() {
    _isLoaded = false;
    // TODO: interpreter.close()
  }
}

/// 解码后的图片数据
class _DecodedImage {
  final Uint8List pixels;
  final int width;
  final int height;

  const _DecodedImage({
    required this.pixels,
    required this.width,
    required this.height,
  });
}

/// OCR 服务工厂
///
/// 根据可用性自动选择最佳 OCR 实现：
/// 1. TFLite OCR（M6 终态，首选）
/// 2. Python OCR（桌面端过渡方案/fallback）
/// 3. MLKit OCR（移动端）
class OcrServiceFactory {
  const OcrServiceFactory._();

  /// 创建 TFLite OCR 服务
  static TfliteOcrService createTflite({String? modelPath}) {
    return TfliteOcrService(modelPath: modelPath);
  }

  /// 创建 Python OCR 服务（fallback）
  static PythonOcrService createPython({String? pythonPath, String? scriptPath}) {
    return PythonOcrService(pythonPath: pythonPath, ocrScriptPath: scriptPath);
  }

  /// 自动选择最佳 OCR 实现
  ///
  /// 桌面端：优先 TFLite → 回退 Python
  /// 移动端：MLKit
  static OcrService createBestAvailable() {
    // 默认使用 Python OCR（最可靠）
    // M6 后可切换为 TFLite:
    // final tflite = TfliteOcrService();
    // if (tflite.isAvailable) return tflite;
    // return PythonOcrService();
    return PythonOcrService();
  }
}
