import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/local_store.dart';
import 'data/order_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/orders_controller.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

class DeliveryBoyApp extends StatelessWidget {
  const DeliveryBoyApp({super.key, this.repository, this.store});

  /// Injectable so tests can supply their own fixtures.
  final OrderRepository? repository;
  final LocalStore? store;

  @override
  Widget build(BuildContext context) {
    // A real run persists to the device. Tests inject a repository and leave
    // the store null, keeping them off the platform channel.
    final effectiveStore =
        store ?? (repository == null ? LocalStore() : null);
    final effectiveRepository =
        repository ?? OrderRepository(store: effectiveStore);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionController(store: effectiveStore),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersController(effectiveRepository)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Delivery Boy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
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
