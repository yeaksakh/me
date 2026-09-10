import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth_api.dart';
import 'data/local_store.dart';
import 'data/shipments_api.dart';
import 'data/warehouse_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/server_config.dart';
import 'state/session_controller.dart';
import 'state/stock_controller.dart';
import 'state/tasks_controller.dart';
import 'theme/app_theme.dart';

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({
    super.key,
    this.repository,
    this.store,
    this.auth,
    this.shipments,
  });

  /// Injectable so tests can supply their own fixtures.
  final WarehouseRepository? repository;
  final LocalStore? store;

  /// Injectable so tests can sign in and work shipments without the network.
  final AuthApi? auth;
  final ShipmentsApi? shipments;

  @override
  Widget build(BuildContext context) {
    // A real run persists to the device. Tests inject a repository and leave
    // the store null, keeping them off the platform channel.
    final effectiveStore = store ?? (repository == null ? LocalStore() : null);
    final effectiveRepository =
        repository ?? WarehouseRepository(store: effectiveStore);

    return MultiProvider(
      providers: [
        // Above the session and the shipments, which both read it.
        ChangeNotifierProvider(
          create: (_) => ServerConfig(store: effectiveStore),
        ),
        ChangeNotifierProvider(
          create: (context) => SessionController(
            store: effectiveStore,
            // Read late, so a server changed on the sign-in screen is the one
            // the next sign-in goes to, without a restart.
            auth: auth ??
                AuthApi(baseUrl: () => context.read<ServerConfig>().baseUrl),
          ),
        ),
        // Not loaded here: shipments need a signed-in token, so the Orders tab
        // loads them when it first appears.
        ChangeNotifierProvider(
          create: (context) => TasksController(
            shipments ??
                ShipmentsApi(
                  baseUrl: () => context.read<ServerConfig>().baseUrl,
                  token: () => context.read<SessionController>().token,
                ),
            onUnauthorized: () => context.read<SessionController>().signOut(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StockController(effectiveRepository, store: effectiveStore)
                ..load(),
        ),
      ],
      child: MaterialApp(
        title: 'WareHouseMgt',
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
