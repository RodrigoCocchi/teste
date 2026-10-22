import 'package:biblia_hinos_ccb/data/agenda_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 20); // quinta 20h
  test('evento único: futuro aparece, passado some', () {
    expect(AgendaEvent(kind: 'Batismo', start: DateTime(2026, 11, 1, 9)).nextAfter(now), DateTime(2026, 11, 1, 9));
    expect(AgendaEvent(kind: 'Batismo', start: DateTime(2026, 10, 1, 9)).nextAfter(now), isNull);
  });

  test('semanal: próxima semana no mesmo dia e hora', () {
    final e = AgendaEvent(kind: 'Ensaio', start: DateTime(2026, 9, 3, 19, 30), repeat: 'weekly'); // quinta
    expect(e.nextAfter(now), DateTime(2026, 10, 29, 19, 30));
    expect(e.nextAfter(DateTime(2026, 10, 22, 19)), DateTime(2026, 10, 22, 19, 30));
  });

  test('mensal: mesmo dia; meses curtos usam o último dia', () {
    final e = AgendaEvent(kind: 'Ensaio', start: DateTime(2026, 1, 31, 15), repeat: 'monthly');
    expect(e.nextAfter(DateTime(2026, 2, 10)), DateTime(2026, 2, 28, 15));
    expect(e.nextAfter(DateTime(2026, 3, 31, 16)), DateTime(2026, 4, 30, 15));
  });

  test('título e alertas', () {
    expect(AgendaEvent(kind: 'Santa Ceia', start: now).displayTitle, 'Santa Ceia');
    expect(alertsLabel([1440, 60]), '1 hora, 1 dia');
    final back = AgendaEvent.fromRow({...AgendaEvent(kind: 'Culto', start: now, alerts: const [30, 120]).toRow(), 'id': 3});
    expect((back.id, back.start), (3, now));
    expect(back.alerts, [30, 120]);
  });
}
