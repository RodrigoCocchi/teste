import 'package:biblia_hinos_ccb/data/database.dart';
import 'package:biblia_hinos_ccb/data/prayer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('pedido entra em oração, é atendido e volta', () async {
    final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
    await PrayerRepository.ensureTable(db.db);
    final r = PrayerRepository(db);
    final id = await r.add('  Pela família  ');
    expect((await r.list(answered: false)).single.text, 'Pela família');
    await r.setAnswered(id, true, note: 'Graças a Deus');
    expect(await r.list(answered: false), isEmpty);
    final a = (await r.list(answered: true)).single;
    expect((a.answered, a.note), (true, 'Graças a Deus'));
    await r.setAnswered(id, false);
    expect((await r.list(answered: false)).single.note, isNull);
    await r.remove(id);
    expect(await r.rawRows(), isEmpty);
    await db.db.close();
  });
}
