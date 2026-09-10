import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/local_store.dart';
import 'data/warehouse_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/session_controller.dart';
import 'state/stock_controller.dart';
import 'state/tasks_controller.dart';
import 'theme/app_theme.dart';

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({super.key, this.repository, this.store});

  /// Injectable so tests can supply their own fixtures.
  final WarehouseRepository? repository;
  final LocalStore? store;

  @override
  Widget build(BuildContext context) {
    // A real run persists to the device. Tests inject a repository and leave
    // the store null, keeping them off the platform channel.
    final effectiveStore = store ?? (repository == null ? LocalStore() : null);
    final effectiveRepository =
        repository ?? WarehouseRepository(store: effectiveStore);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionController(store: effectiveStore),
        ),
        ChangeNotifierProvider(
          create: (_) => TasksController(effectiveRepository)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StockController(effectiveRepository, store: effectiveStore)
                ..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Warehouse',
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
    final signedIn =
        context.select<SessionController, bool>((s) => s.isSignedIn);
    return signedIn ? const HomeShell() : const LoginScreen();
  }
}
