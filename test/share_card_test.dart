import 'package:biblia_hinos_ccb/data/rehearsal_repository.dart';
import 'package:biblia_hinos_ccb/screens/rehearsal_screen.dart';
import 'package:biblia_hinos_ccb/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final r = Rehearsal(
    at: DateTime(2026, 10, 22, 19, 30),
    place: 'Jardim Rina',
    kind: 'Ensaio local',
    counts: const {'Violino': 12, 'Clarinete': 6, 'Organistas': 5, 'Visitas': 3},
  );

  test('texto para WhatsApp com igreja, data, naipes e total', () {
    final t = rehearsalShare(r, defaultCountGroups).text;
    expect(t, contains('*ENSAIO LOCAL*'));
    expect(t, contains('*Jardim Rina*'));
    expect(t, contains('quinta-feira, 22 de outubro de 2026 · 19:30'));
    expect(t, contains('Violino: 12'));
    expect(t, contains('_Subtotal: 12_'));
    expect(t, contains('*Total geral: 26*'));
    expect(t, isNot(contains('Viola:')));
  });

  testWidgets('cartão desenha sem erro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ShareCardScreen(data: rehearsalShare(r, defaultCountGroups))));
    expect(find.text('Total geral'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
