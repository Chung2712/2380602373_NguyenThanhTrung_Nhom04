import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyenthanhtrung_smartguard_flutter/main.dart';

void main() {
  testWidgets('Trang đăng nhập Flutter có nút đăng nhập', (tester) async {
    await tester.pumpWidget(const SmartGuardApp(faceLockEnabled: false));
    expect(find.text('SmartGuard'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });
}
