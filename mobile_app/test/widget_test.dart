// استيراد مكتبة واجهات Flutter
import 'package:flutter/material.dart';
// استيراد مكتبة الاختبارات الخاصة بـ Flutter
import 'package:flutter_test/flutter_test.dart';

// استيراد التطبيق الرئيسي من مشروعك
import 'package:smart_memory_app/main.dart';

void main() {
  // تعريف اختبار واجهة جديد
  testWidgets('App bar title test', (WidgetTester tester) async {
    // بناء التطبيق وضخ إطار جديد (render)
    await tester.pumpWidget(MyApp());

    // التحقق أن عنوان الـ AppBar يحتوي على النص "ذاكرتي الذكية"
    expect(find.text('ذاكرتي الذكية'), findsOneWidget);
  });
}