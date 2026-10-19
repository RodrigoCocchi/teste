import 'package:biblia_hinos_ccb/services/ccb_relatorio.dart';
import 'package:biblia_hinos_ccb/services/rel_nearby.dart';
import 'package:flutter_test/flutter_test.dart';

// Trechos no formato devolvido pelo site (diagnóstico de 19/10/2026).
const _lista = '''
<table class="table table-hover table-sm"><thead><tr><th>Exibindo 5 de 13</th></tr></thead><tbody>
<tr><td><div onclick="selectLocation(this)" data-id="12156">
  <div style="text-align: left;"><strong class="nome-localidade">Br&#225;s - Central</strong></div>
  <small style="display: flex;" class="text-muted">BR-21-0008</small>
  <div style="text-align: initial;">S&#227;o Paulo, SP, Brasil</div>
  <div style="text-align: initial;">Rua Visconde de Parna&#237;ba, 1616</div>
</div></td></tr>
<tr><td><div onclick="selectLocation(this)" data-id="2683">
  <div style="text-align: left;"><strong class="nome-localidade">Flexal II</strong></div>
  <small style="display: flex;" class="text-muted">BR-06-0042</small>
  <div style="text-align: initial;">Cariacica, ES, Brasil</div>
  <div style="text-align: initial;">Rua da Galeria, s/n</div>
</div></td></tr>
</tbody><tfoot><tr><td colspan="2" align="center">
<button type="submit" class="button" value="2">Próximo</button></td></tr></tfoot></table>''';

const _detalhe = '''
<table class="table table-sm" border="0"><tbody>
<tr><td><div class="card detalhe"><label class="nome-grupos mb-1"><strong>Br&#225;s</strong></label>
<p><small class="float-start"><strong>CENTRAL</strong></small></p></div></td></tr>
<tr><td><div class="card detalhe"><label class="nome-grupos mb-3"><strong>Localização</strong></label>
<p><strong class="">Logradouro:</strong> Rua Visconde de Parna&#237;ba, 1616</p>
<p><strong class="">CEP:</strong> 03164-300</p></div></td></tr>
<tr><td><div class="card detalhe"><label class="nome-grupos mb-1"><strong>Dias de Culto</strong></label>
<p class="mt-3"><strong class="">Culto Oficial</strong></p>
<p>&nbsp;&nbsp;Domingo - 18:30  </p></div></td></tr>
<tr><td><div class="card detalhe"><label class="nome-grupos"><strong>Ministério</strong></label>
<p>&nbsp;&nbsp;Fulano</p><p>&nbsp;&nbsp;Fulano</p></div></td></tr>
<tr><td><div class="card detalhe"><label class="nome-grupos mb-3"><strong>Telefone(s)</strong></label>
<p>+55 (11) 3299-0200</p></div></td></tr></tbody></table>''';

void main() {
  test('lista do relatório vira casas de oração', () {
    final p = parseRelTable(_lista);
    expect(p.places, hasLength(2));
    final b = p.places.first;
    expect(b.id, '12156');
    expect(b.name, 'Brás - Central');
    expect(b.code, 'BR-21-0008');
    expect(b.city, 'São Paulo, SP, Brasil');
    expect(b.address, 'Rua Visconde de Parnaíba, 1616');
    expect(p.info, 'Exibindo 5 de 13');
    expect(p.hasNext, isTrue);
  });

  test('detalhe em blocos, sem repetições seguidas', () {
    final d = parseRelDetail(_detalhe);
    expect(d.map((s) => s.title), ['Brás', 'Localização', 'Dias de Culto', 'Ministério', 'Telefone(s)']);
    expect(d[1].lines.first, 'Logradouro: Rua Visconde de Parnaíba, 1616');
    expect(d[2].lines, ['Culto Oficial', 'Domingo - 18:30']);
    expect(d[3].lines, ['Fulano']);
    expect(d[4].lines, ['+55 (11) 3299-0200']);
  });

  test('opções ignoram "Selecione"', () {
    final o = parseRelOptions('{"list":[{"Text":"Selecione","Value":"0"},{"Text":"Brasil","Value":"1"}]}');
    expect(o.map((e) => e.text), ['Brasil']);
  });

  test('estado e cidade do GPS batem com as listas do relatório', () {
    const estados = [RelOption('ESPÍRITO SANTO', '376'), RelOption('SÃO PAULO', '21')];
    expect(matchOption(estados, ['State of São Paulo'])?.value, '21');
    expect(matchOption(estados, ['ES'])?.value, '376');
    expect(matchOption(estados, [null, 'Sao Paulo'])?.value, '21');
    expect(ufOf('ESPÍRITO SANTO'), 'ES');
    const cidades = [RelOption('Vitória', '2328'), RelOption('Cariacica', '2329')];
    expect(matchOption(cidades, ['', 'Vitoria'])?.value, '2328');
  });
}
