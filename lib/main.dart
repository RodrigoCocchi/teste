import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'services/app_services.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await App.init();
  runApp(const BibliaHinosApp());
}

class BibliaHinosApp extends StatelessWidget {
  const BibliaHinosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = App.I.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Bíblia & Hinos CCB',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(settings.theme),
        home: const Shell(),
      ),
    );
  }
}
