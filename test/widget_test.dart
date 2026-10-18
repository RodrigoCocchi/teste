import 'dart:io';

import 'package:biblia_hinos_ccb/main.dart';
import 'package:biblia_hinos_ccb/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Alterna I/O real (sqflite ffi) e quadros até a tela estabilizar.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

void main() {
  sqfliteFfiInit();

  testWidgets('abre o app e navega pelas abas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('bh_widget');
      await App.init(dbPath: inMemoryDatabasePath, factory: databaseFactoryFfi, dataDir: dir.path);
    });
    await tester.pumpWidget(const BibliaHinosApp());
    await tester.pump();
    expect(find.text('Bíblia & Hinos CCB'), findsOneWidget);
    expect(find.text('Estudo do Dia'), findsOneWidget);
    expect(find.text('Plano de Leitura', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Bíblia').last);
    await settle(tester);
    expect(find.text('Gênesis'), findsOneWidget);

    await tester.tap(find.text('Quiz').last);
    await settle(tester);
    expect(find.text('Começar'), findsOneWidget);

    await tester.tap(find.text('Hinário').last);
    await settle(tester);
    expect(find.text('Em Dó'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('Favoritos').last);
    await settle(tester);
    expect(find.text('Versículos'), findsOneWidget);

    await tester.runAsync(() => App.I.db.db.close());
  });
}
