import 'package:biblia_hinos_ccb/data/database.dart';
import 'package:biblia_hinos_ccb/data/places_repository.dart';
import 'package:biblia_hinos_ccb/data/prayer_repository.dart';
import 'package:biblia_hinos_ccb/services/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> _open() async {
  final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
  await PlacesRepository.ensureTable(db.db);
  await PrayerRepository.ensureTable(db.db);
  return db;
}

void main() {
  sqfliteFfiInit();
  test('backup leva favoritos, marcações, casas, oração e progresso para outro aparelho', () async {
    final a = await _open();
    await a.db.insert('favorite', {'kind': 'verse', 'ref_key': '43003016', 'label': 'João 3:16', 'created_at': 1});
    await a.db.insert('bookmark', {'verse_id': 43003016, 'color': 2, 'note': 'Amor de Deus', 'updated_at': 1});
    await a.db.insert('reading_progress', {'book_id': 1, 'chapter': 1, 'done_at': 1});
    await a.db.insert('saved_place', {'id': '12156', 'name': 'Brás', 'detail': '[]', 'is_home': 1, 'remind': 60,
        'saved_at': 1, 'updated_at': 1});
    await PrayerRepository(a).add('Pela família');
    final raw = encodeBackup(await buildBackup(a.db));
    await a.db.close();

    final b = await _open();
    expect(await restoreBackup(b.db, raw), 5);
    // Restaurar de novo não duplica.
    await restoreBackup(b.db, raw);
    expect((await b.db.query('favorite')).length, 1);
    expect((await b.db.query('prayer')).length, 1);
    final place = (await b.db.query('saved_place')).single;
    expect((place['is_home'], place['remind']), (1, 60));
    expect((await b.db.query('bookmark')).single['note'], 'Amor de Deus');
    await expectLater(restoreBackup(b.db, '{"app":"outro"}'), throwsFormatException);
    await expectLater(restoreBackup(b.db, 'lixo'), throwsFormatException);
    await b.db.close();
  });
}
