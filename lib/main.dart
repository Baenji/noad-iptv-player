import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/shell.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'noAd IPTV Player',
      size: Size(1360, 860),
      minimumSize: Size(1100, 680),
      center: true,
      backgroundColor: C.bg,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final storage = await Storage.open();
  runApp(NoAdApp(state: AppState(storage)));
}

class NoAdApp extends StatelessWidget {
  const NoAdApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'noAd IPTV Player',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Scaffold(body: Shell()),
      ),
    );
  }
}
