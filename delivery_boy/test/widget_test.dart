import 'package:delivery_boy/app.dart';
import 'package:delivery_boy/data/order_repository.dart';
import 'package:delivery_boy/models/order.dart';
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

  testWidgets('a cash delivery cannot be confirmed until the cash is ticked',
      (tester) async {
    final repository = OrderRepository()..latency = Duration.zero;
    await tester.pumpWidget(DeliveryBoyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    // ORD-1042 is a cash order.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm pickup'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
    await tester.pumpAndSettle();

    // The sheet opens with the confirm button disabled.
    final confirm = find.widgetWithText(ElevatedButton, 'Confirm delivery');
    expect(confirm, findsOneWidget);
    expect(find.textContaining('I collected'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    // Ticking the cash box enables it, and confirming closes the order.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.textContaining('Delivered.'), findsOneWidget);

    final orders = await repository.fetchOrders();
    final order = orders.firstWhere((o) => o.code == 'ORD-1042');
    expect(order.status, OrderStatus.delivered);
    expect(order.cashCollected, isTrue);
  });
}
