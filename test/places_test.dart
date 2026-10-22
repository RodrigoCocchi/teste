import 'package:biblia_hinos_ccb/data/places_repository.dart';
import 'package:biblia_hinos_ccb/services/ccb_relatorio.dart';
import 'package:flutter_test/flutter_test.dart';

// Bloco "Dias de Culto" como veio do site (Jardim Rina, 22/10/2026).
const _secs = [
  RelSection('Jardim Rina', ['CENTRAL']),
  RelSection('Dias de Culto', [
    'DN 2N 5N (RJM-DM)',
    'Reunião de Jovens e Menores',
    'Domingo - 10:00',
    'Culto Oficial',
    'Domingo - 18:30',
    'Segunda-feira - 19:30',
    'Quinta-feira - 19:30',
  ]),
  RelSection('Telefone(s)', ['+55 (11) 2379-4172']),
];

void main() {
  test('lê os horários por tipo de culto', () {
    final c = parseCultos(_secs);
    expect(c.map((x) => '${x.kind}|${x.dayName}|${x.time}'), [
      'Culto Oficial|Segunda|19:30',
      'Culto Oficial|Quinta|19:30',
      'Reunião de Jovens e Menores|Domingo|10:00',
      'Culto Oficial|Domingo|18:30',
    ]);
  });

  test('próximo culto', () {
    final c = parseCultos(_secs);
    // Quinta 22/10/2026 às 18h -> quinta 19:30.
    var n = nextCulto(c, DateTime(2026, 10, 22, 18))!;
    expect((n.$1.dayName, n.$2), ('Quinta', DateTime(2026, 10, 22, 19, 30)));
    // Quinta às 20h -> domingo 10:00 (RJM).
    n = nextCulto(c, DateTime(2026, 10, 22, 20))!;
    expect((n.$1.kind, n.$2), ('Reunião de Jovens e Menores', DateTime(2026, 10, 25, 10)));
    // Domingo 19h -> segunda 19:30.
    n = nextCulto(c, DateTime(2026, 10, 25, 19))!;
    expect(n.$2, DateTime(2026, 10, 26, 19, 30));
  });

  test('detalhe salvo volta igual', () {
    final raw = PlacesRepository.encodeSections(_secs);
    final back = PlacesRepository.decodeSections(raw);
    expect(back.map((s) => s.title), _secs.map((s) => s.title));
    expect(back[1].lines, _secs[1].lines);
  });
}
