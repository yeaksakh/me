import 'package:delivery_boy/app.dart';
import 'package:delivery_boy/data/order_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signing in reaches the dashboard and shows requests',
      (tester) async {
    final repository = OrderRepository()..latency = Duration.zero;
    await tester.pumpWidget(DeliveryBoyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Boy'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('New requests'), findsOneWidget);
    expect(find.text('ORD-1042'), findsOneWidget);
  });

  testWidgets('accepting an order opens the active delivery screen',
      (tester) async {
    final repository = OrderRepository()..latency = Duration.zero;
    await tester.pumpWidget(DeliveryBoyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept order').first);
    await tester.pumpAndSettle();

    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Confirm pickup'), findsOneWidget);
  });
}
