import 'package:biblia_hinos_ccb/services/profile.dart';
import 'package:biblia_hinos_ccb/services/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aviso do aniversário de batismo às 8h com os anos', () {
    final p = Profile(name: 'Rodrigo Silva', baptismDate: DateTime(2010, 11, 14), baptismChurch: 'Brás');
    final a = baptismAlerts(p, DateTime(2026, 10, 22, 20));
    expect(a.length, 3);
    expect(a.first.when, DateTime(2026, 11, 14, 8));
    expect(a.first.body, 'Rodrigo, hoje faz 16 anos do seu batismo (Brás). Deus seja louvado!');
    expect(a.first.payload, 'baptism:16');
    expect(baptismAlerts(Profile(baptismDate: DateTime(2010, 11, 14), remindBaptism: false), DateTime(2026)), isEmpty);
    expect(baptismAlerts(const Profile(), DateTime(2026)), isEmpty);
  });
}
