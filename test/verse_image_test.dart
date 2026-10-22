import 'package:biblia_hinos_ccb/screens/verse_image_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cartão do versículo desenha sem estourar, nos dois formatos', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final long = List.filled(40, 'Porque Deus amou o mundo de tal maneira').join(' ');
    for (final text in ['Jesus chorou.', long]) {
      await t.pumpWidget(MaterialApp(home: VerseImageScreen(text: text, reference: 'João 11:35 (ARC)')));
      expect(find.text('João 11:35 (ARC)'), findsOneWidget);
      await t.tap(find.text('Status'));
      await t.pump();
      expect(t.takeException(), isNull);
    }
  });
}
