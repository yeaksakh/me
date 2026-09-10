import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only. The app is used one-handed with a box in the other arm,
  // and every screen is laid out for that; a phone turned on its side mid-pick
  // would reflow the item list under the packer's thumb.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const WarehouseApp());
}
