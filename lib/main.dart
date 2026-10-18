import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'services/app_services.dart';
import 'services/settings.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

/// Mostra a interface imediatamente e inicializa banco/conteúdo em seguida.
/// Se algo falhar, o erro aparece na tela em vez de uma tela branca.
class BootApp extends StatefulWidget {
  const BootApp({super.key});
  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  late Future<void> _init = _start();

  Future<void> _start() => App.init().timeout(const Duration(seconds: 40));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          return const BibliaHinosApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(ReadingTheme.light),
          home: Scaffold(
            backgroundColor: AppColors.navy,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: snap.hasError
                      ? SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline, color: AppColors.gold, size: 48),
                            const SizedBox(height: 12),
                            const Text('Não foi possível iniciar o aplicativo',
                                style: TextStyle(color: Colors.white, fontSize: 18)),
                            const SizedBox(height: 12),
                            SelectableText('${snap.error}\n\n${snap.stackTrace ?? ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() => _init = _start()),
                              child: const Text('Tentar novamente'),
                            ),
                          ]),
                        )
                      : const Column(mainAxisSize: MainAxisSize.min, children: [
                          Image(image: AssetImage('assets/images/icon.png'), width: 180),
                          SizedBox(height: 28),
                          CircularProgressIndicator(color: AppColors.gold),
                        ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
