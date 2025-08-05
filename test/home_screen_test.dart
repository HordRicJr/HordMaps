import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hordmaps/screens/home_screen.dart';
import 'package:hordmaps/services/advanced_location_service.dart';

void main() {
  group('Home Screen Tests', () {
    testWidgets('Home screen displays correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: AdvancedLocationService.instance,
            child: const HomeScreen(),
          ),
        ),
      );

      // Wait for the initial frame
      await tester.pump();

      // Check if there are some containers/widgets for the dynamic content
      expect(find.byType(Container), findsAtLeast(1));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Quick Actions Grid is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: AdvancedLocationService.instance,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for GridView which contains our quick actions
      expect(find.byType(GridView), findsAtLeast(1));
    });

    testWidgets('Recent Routes section exists', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: AdvancedLocationService.instance,
            child: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if recent routes section is present
      expect(find.text('Routes récentes'), findsAtLeast(1));
    });
  });
}
