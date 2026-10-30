import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/yai_theme.dart';
import 'features/events/calendar_controller.dart';
import 'features/events/data/event_local_data_source.dart';
import 'features/events/data/event_remote_data_source.dart';
import 'features/events/ui/calendar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm the glass shaders before the first frame.
  await LiquidGlassWidgets.initialize();

  // Composition root: plain constructor injection, no DI/service locator.
  final database = await AppDatabase.open();
  final local = EventLocalDataSource(database.db);
  final api = ApiClient(
      // tokenProvider: () => authStore.accessToken(),
      );
  final sync = SyncEngine(local: local, remote: EventRemoteDataSource(api));
  final controller = CalendarController(local, sync);

  // Load the cached month before the first frame: the UI paints with real
  // data immediately, online or not. Sync starts afterwards in the background.
  await controller.showMonth(DateTime.now());
  sync.start();

  runApp(LiquidGlassWidgets.wrap(
    // MaterialApp: glass follows the app's theme mode, not the raw OS setting.
    brightnessResolver: Theme.maybeBrightnessOf,
    adaptiveQuality: true,
    child: CalendarApp(controller: controller, sync: sync),
  ));
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key, required this.controller, required this.sync});

  final CalendarController controller;
  final SyncEngine sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yai Calendar',
      debugShowCheckedModeBanner: false,
      theme: YaiPalette.light.toTheme(),
      darkTheme: YaiPalette.dark.toTheme(),
      themeMode: ThemeMode.system,
      home: CalendarScreen(controller: controller, sync: sync),
    );
  }
}
