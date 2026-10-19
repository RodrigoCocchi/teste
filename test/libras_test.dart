import 'package:biblia_hinos_ccb/data/libras_phrases.dart';
import 'package:biblia_hinos_ccb/data/libras_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('página do VLibras traz as frases pedidas e o widget oficial', () {
    final html = librasHtml(librasPhrases);
    for (final f in ['A paz de Deus', 'Amém', 'Jesus', 'Deus', 'Glória', 'Aleluia', 'Vai com Deus']) {
      expect(html, contains('<p class="frase">$f</p>'));
    }
    expect(html, contains('https://vlibras.gov.br/app/vlibras-plugin.js'));
    expect(librasHtml({'<x>': ['a & b']}), contains('a &amp; b'));
  });
}
