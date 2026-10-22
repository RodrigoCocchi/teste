import 'package:biblia_hinos_ccb/data/youth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('treino mostra só a primeira letra', () {
    expect(firstLetters('O Senhor é o meu pastor; nada me faltará.'), 'O S_____ é o m__ p_____; n___ m_ f______.');
  });

  test('passo de hino reconhece o número', () {
    expect(RjmStep('Hino', detail: '120').hymnNumber, 120);
    expect(RjmStep('Hino de abertura', detail: 'hino 5').hymnNumber, 5);
    expect(RjmStep('Oração', detail: '12').hymnNumber, isNull);
  });

  test('reunião salva e volta igual', () {
    final s = RjmSession(
      at: DateTime(2026, 10, 25, 10),
      place: 'Jardim Rina',
      steps: [for (final t in defaultRjmTemplate) RjmStep(t)]..first.done = true,
      recits: [RjmRecit('Ana', 'Salmos 23:1', done: true), RjmRecit('Pedro', 'João 3:16')],
    );
    final back = RjmSession.fromRow({...s.toRow(), 'id': 1});
    expect(back.steps.length, defaultRjmTemplate.length);
    expect(back.done, 1);
    expect(back.recits.map((r) => (r.person, r.done)), [('Ana', true), ('Pedro', false)]);
  });

  test('recitativo guarda texto e situação', () {
    final r = Recitativo.fromRow({...const Recitativo(person: 'Ana', ref: 'Salmos 23:1', text: 'O Senhor é o meu pastor', status: 'pronto').toRow(), 'id': 2});
    expect((r.person, r.status, r.recitedAt), ('Ana', 'pronto', null));
  });
}
