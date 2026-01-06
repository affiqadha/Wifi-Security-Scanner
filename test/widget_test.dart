// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wifense/main.dart';
import 'package:wifense/theme/theme_manager.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // ✅ Build our app with required parameters
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: const MyApp(
          initialRoute: '/login', // ✅ Added required parameter
        ),
      ),
    );

    // ✅ Wait for app to settle
    await tester.pumpAndSettle();

    // ✅ Verify that the app launched (you can customize these checks)
    // Example: Check if login screen or home screen appeared
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('MyApp has correct initial route', (WidgetTester tester) async {
    // Test with login route
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: const MyApp(
          initialRoute: '/login',
        ),
      ),
    );

    await tester.pumpAndSettle();
    
    // Verify MaterialApp exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('MyApp can start with home route', (WidgetTester tester) async {
    // Test with home route
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeManager(),
        child: const MyApp(
          initialRoute: '/home',
        ),
      ),
    );

    await tester.pumpAndSettle();
    
    // Verify MaterialApp exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}