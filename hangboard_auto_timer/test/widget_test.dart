import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangboard_auto_timer/main.dart';

void main() {
  testWidgets('App renders loading indicator initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HangboardApp());

    // The app shows a loading indicator while initializing
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
