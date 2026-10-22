import 'package:biblia_hinos_ccb/data/organ_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cultos do mês: domingos 18:30 e quintas 19:30 de outubro/2026', () {
    final s = monthSlots(2026, 10, [(DateTime.sunday, 18, 30), (DateTime.thursday, 19, 30)]);
    expect(s.length, 9); // 4 domingos + 5 quintas
    expect(s.first, DateTime(2026, 10, 1, 19, 30));
    expect(s.last, DateTime(2026, 10, 29, 19, 30));
  });

  test('rodízio: uma por culto, continua no mês seguinte', () {
    final slots = [DateTime(2026, 10, 1, 19, 30), DateTime(2026, 10, 4, 18, 30), DateTime(2026, 10, 8, 19, 30)];
    final (d, next) = generateRotation(slots: slots, organistIds: [1, 2], split: false);
    expect(d.map((x) => (x.organistId, x.part)), [(1, 'Meia hora e culto'), (2, 'Meia hora e culto'), (1, 'Meia hora e culto')]);
    expect(next, 1);
    final (d2, _) = generateRotation(slots: slots.take(1).toList(), organistIds: [1, 2], split: false, startIndex: next);
    expect(d2.single.organistId, 2);
  });

  test('rodízio dividido: meia hora e culto com organistas diferentes', () {
    final (d, next) = generateRotation(slots: [DateTime(2026, 10, 1, 19, 30)], organistIds: [1, 2, 3], split: true);
    expect(d.map((x) => (x.organistId, x.part)), [(1, 'Meia hora'), (2, 'Culto')]);
    expect(next, 2);
    expect(d.first.playAt, DateTime(2026, 10, 1, 19));
    expect(d.last.playAt, DateTime(2026, 10, 1, 19, 30));
  });
}
