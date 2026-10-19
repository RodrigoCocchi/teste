import 'package:biblia_hinos_ccb/services/ccb_relatorio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tabela do relatório vira linhas com data-id', () {
    const html = '<table><thead><tr><th>Localidade</th><th>Dia</th></tr></thead>'
        '<tbody><tr data-id="123"><td><b>Brás</b></td><td>Domingo<br>19h00</td></tr>'
        '<tr><td></td></tr></tbody></table><span>Exibindo 1 de 24254</span>';
    final p = parseRelTable(html);
    expect(p.headers, ['Localidade', 'Dia']);
    expect(p.rows, hasLength(1));
    expect(p.rows.first.id, '123');
    expect(p.rows.first.cells, ['Brás', 'Domingo · 19h00']);
    expect(p.info, 'Exibindo 1 de 24254');
  });

  test('opções ignoram "Selecione"', () {
    final o = parseRelOptions('{"list":[{"Text":"Selecione","Value":""},{"Text":"Brasil","Value":"7"}]}');
    expect(o.map((e) => e.text), ['Brasil']);
  });
}
