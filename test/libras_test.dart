import 'package:biblia_hinos_ccb/data/libras_page.dart';
import 'package:biblia_hinos_ccb/data/libras_phrases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frases pedidas estão na lista', () {
    final all = librasPhrases.values.expand((e) => e).toSet();
    for (final f in ['A paz de Deus', 'Amém', 'Jesus', 'Deus', 'Glória', 'Aleluia', 'Vai com Deus']) {
      expect(all, contains(f));
    }
  });

  test('página só tem o avatar e o texto: sem botões para o VLibras traduzir', () {
    expect(librasHtml, contains('https://vlibras.gov.br/app/vlibras-plugin.js'));
    expect(librasHtml, contains('function mostrar('));
    expect(librasHtml, isNot(contains('<button')));
    expect(librasHtml, isNot(contains('<textarea')));
  });
}
