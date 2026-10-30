import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/app_database.dart';
import 'core/environment.dart';
import 'core/network/api_client.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/yai_theme.dart';
import 'features/events/calendar_controller.dart';
import 'features/events/data/event_local_data_source.dart';
import 'features/events/data/event_remote_data_source.dart';
import 'features/events/data/supabase_event_remote.dart';
import 'features/events/ui/calendar_screen.dart';
import 'features/events/ui/join_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm the glass shaders before the first frame.
  await LiquidGlassWidgets.initialize();

  final database = await AppDatabase.open();
  final local = EventLocalDataSource(database.db);
  final prefs = await SharedPreferences.getInstance();

  runApp(LiquidGlassWidgets.wrap(
    // MaterialApp: glass follows the app's theme mode, not the raw OS setting.
    brightnessResolver: Theme.maybeBrightnessOf,
    adaptiveQuality: true,
    child: CalendarApp(local: local, prefs: prefs),
  ));
}

class CalendarApp extends StatefulWidget {
  const CalendarApp({super.key, required this.local, required this.prefs});

  final EventLocalDataSource local;
  final SharedPreferences prefs;

  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  static const _codeKey = 'calendar_code';

  String? _code;
  CalendarController? _controller;
  SyncEngine? _sync;

  @override
  void initState() {
    super.initState();
    _code = widget.prefs.getString(_codeKey);
    // Without a configured backend the app is a plain offline calendar.
    if (_code != null || !SharedConfig.configured) unawaited(_open());
  }

  /// Composition root for one calendar: plain constructor injection.
  Future<void> _open() async {
    final code = _code;
    final sync = SyncEngine(
      local: widget.local,
      remote: SharedConfig.configured && code != null
          ? SupabaseEventRemote(
              url: SharedConfig.url,
              anonKey: SharedConfig.anonKey,
              code: code,
            )
          : EventRemoteDataSource(ApiClient()),
      pollEvery: SharedConfig.configured ? const Duration(seconds: 20) : null,
    );
    final controller = CalendarController(widget.local, sync);
    // Paint the cached month immediately, online or not; sync runs after.
    await controller.showMonth(DateTime.now());
    if (SharedConfig.configured && code != null || !SharedConfig.configured) {
      sync.start();
    }
    if (!mounted) return;
    setState(() {
      _sync = sync;
      _controller = controller;
    });
  }

  Future<void> _join(String code) async {
    // A different calendar: drop the other one's cached events and cursor.
    await widget.local.clearAll();
    await widget.prefs.setString(_codeKey, code);
    setState(() => _code = code);
    await _open();
  }

  Future<void> _leave() async {
    _sync?.dispose();
    await widget.local.clearAll();
    await widget.prefs.remove(_codeKey);
    setState(() {
      _code = null;
      _controller = null;
      _sync = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller, sync = _sync;
    return MaterialApp(
      title: 'Yai Calendar',
      debugShowCheckedModeBanner: false,
      theme: YaiPalette.light.toTheme(),
      darkTheme: YaiPalette.dark.toTheme(),
      themeMode: ThemeMode.system,
      home: controller != null && sync != null
          ? CalendarScreen(
              controller: controller,
              sync: sync,
              code: _code,
              onLeave: _code == null ? null : _leave,
            )
          : _code == null && SharedConfig.configured
              ? JoinScreen(onJoin: _join)
              : const Scaffold(body: SizedBox.shrink()),
    );
  }
}
