import 'package:biblia_hinos_ccb/data/rehearsal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('somas: por naipe, músicos, organistas e total geral', () {
    final t = totalsOf(defaultCountGroups, {
      'Violino': 12, 'Viola': 3, 'Violoncelo': 2,
      'Clarinete': 6, 'Sax alto': 4,
      'Trompete': 5, 'Trombone': 3, 'Tuba': 1,
      'Organistas': 7,
      'Alunos do GEM': 9, 'Encarregados locais': 2, 'Visitas': 4,
    });
    expect(t.byGroup['Cordas'], 17);
    expect(t.byGroup['Madeiras'], 10);
    expect(t.byGroup['Metais'], 9);
    expect(t.musicians, 36);
    expect(t.organists, 7);
    expect(t.total, 58);
  });

  test('lista editável volta igual e registro do ensaio guarda contagem', () {
    final back = decodeGroups(encodeGroups(defaultCountGroups));
    expect(back.map((g) => g.name), defaultCountGroups.map((g) => g.name));
    expect(back.first.musicians, isTrue);
    final r = Rehearsal.fromRow({...Rehearsal(at: DateTime(2026, 10, 22), counts: const {'Violino': 3}).toRow(), 'id': 1});
    expect(r.counts, {'Violino': 3});
  });
}
