import 'package:biblia_hinos_ccb/services/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('próximos aniversários de batismo com os anos certos', () {
    final b = DateTime(2010, 11, 14);
    expect(nextAnniversaries(b, DateTime(2026, 10, 22)), [
      (DateTime(2026, 11, 14), 16),
      (DateTime(2027, 11, 14), 17),
      (DateTime(2028, 11, 14), 18),
    ]);
    // No próprio dia ainda conta.
    expect(nextAnniversaries(b, DateTime(2026, 11, 14, 22)).first, (DateTime(2026, 11, 14), 16));
    expect(baptismYearsToday(b, DateTime(2026, 11, 14, 9)), 16);
    expect(baptismYearsToday(b, DateTime(2026, 11, 15)), isNull);
    // Batizado este ano: o primeiro aniversário é no ano que vem.
    expect(nextAnniversaries(DateTime(2026, 3, 1), DateTime(2026, 10, 22)).first, (DateTime(2027, 3, 1), 1));
  });

  test('29 de fevereiro vira 28 em ano comum', () {
    expect(anniversaryIn(DateTime(2008, 2, 29), 2027), DateTime(2027, 2, 28));
    expect(anniversaryIn(DateTime(2008, 2, 29), 2028), DateTime(2028, 2, 29));
  });

  test('perfil salva e carrega; campos vazios são opcionais', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    expect(Profile.load(p).isEmpty, isTrue);
    await Profile(name: 'Rodrigo Silva', baptismDate: DateTime(2010, 11, 14), baptismChurch: 'Brás').save(p);
    final l = Profile.load(p);
    expect((l.firstName, l.baptismDate, l.baptismChurch, l.comum), ('Rodrigo', DateTime(2010, 11, 14), 'Brás', ''));
    expect(Profile.fromJson(l.toJson()).baptismDate, DateTime(2010, 11, 14));
  });
}

