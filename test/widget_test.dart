/// Widget 测试入口
///
/// M1 阶段：基础 smoke test，确保应用能启动
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interknot_auth_flutter/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: InterKnotApp()),
    );
    // 验证应用能启动（后续里程碑补充详细测试）
    expect(find.byType(InterKnotApp), findsOneWidget);
  });
}
