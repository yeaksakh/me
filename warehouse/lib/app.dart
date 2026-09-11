import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/auth_api.dart';
import 'data/hrm_api.dart';
import 'data/local_store.dart';
import 'data/shipments_api.dart';
import 'data/warehouse_repository.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/alerts.dart';
import 'services/order_watcher.dart';
import 'state/hrm_controller.dart';
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
    this.hrm,
    this.watchForNewOrders = true,
  });

  /// Injectable so tests can supply their own fixtures.
  final WarehouseRepository? repository;
  final LocalStore? store;

  /// Injectable so tests can sign in and work shipments without the network.
  final AuthApi? auth;
  final ShipmentsApi? shipments;
  final HrmApi? hrm;

  /// Off in tests: the watcher runs on a timer, and a test must end with none
  /// pending.
  final bool watchForNewOrders;

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
          create: (context) => HrmController(
            hrm ??
                HrmApi(ApiClient(
                  baseUrl: () => context.read<ServerConfig>().baseUrl,
                  token: () => context.read<SessionController>().token,
                )),
            userId: () => context.read<SessionController>().staff?.id,
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
        title: 'Yeaksarehouse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // Light only: the palette is the app's own, and a warehouse handset
        // set to dark must still show the same colours as the one beside it.
        themeMode: ThemeMode.light,
        home: _Root(watchForNewOrders: watchForNewOrders),
      ),
    );
  }
}

/// The sign-in screen or the app, and -- while someone is signed in -- the
/// watcher that rings for a new order. It starts with a session and stops
/// with it, so the next person on the handset is not rung for the last one's
/// orders.
class _Root extends StatefulWidget {
  const _Root({required this.watchForNewOrders});

  final bool watchForNewOrders;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  OrderWatcher? _watcher;
  bool _wasSignedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signedIn = context.watch<SessionController>().isSignedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    if (!widget.watchForNewOrders) return;
    if (signedIn) {
      _watcher ??= OrderWatcher(
        tasks: context.read<TasksController>(),
        alerts: Alerts(),
      );
      _watcher!.start();
    } else {
      _watcher?.stop();
    }
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn =
        context.select<SessionController, bool>((s) => s.isSignedIn);
    return signedIn ? const HomeShell() : const LoginScreen();
  }
}
