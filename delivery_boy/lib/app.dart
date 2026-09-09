import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/order_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/orders_controller.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

class DeliveryBoyApp extends StatelessWidget {
  const DeliveryBoyApp({super.key, this.repository});

  /// Injectable so tests can supply their own fixtures.
  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(
          create: (_) => OrdersController(repository ?? OrderRepository())..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Delivery Boy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<SessionController, bool>((s) => s.isSignedIn);
    return signedIn ? const HomeShell() : const LoginScreen();
  }
}
