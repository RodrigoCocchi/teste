import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Partes que a organista toca.
const List<String> organParts = [
  'Meia hora e culto',
  'Meia hora',
  'Culto',
  'Reunião de Jovens e Menores',
  'Ensaio',
  'Santa Ceia',
  'Batismo',
  'Outro',
];

class Organist {
  const Organist(this.id, this.name, this.isMe, this.position);
  final int id;
  final String name;
  final bool isMe;
  final int position;
}

/// Um compromisso da escala. [at] é o horário do culto; "meia hora" começa 30 min antes.
class OrganDuty {
  const OrganDuty({this.id, required this.at, required this.part, this.organistId, this.place = '', this.notes = ''});
  final int? id;
  final DateTime at;
  final String part;
  final int? organistId;
  final String place;
  final String notes;

  bool get startsHalfHourBefore => part.startsWith('Meia hora');

  /// Quando a organista precisa começar a tocar.
  DateTime get playAt => startsHalfHourBefore ? at.subtract(const Duration(minutes: 30)) : at;

  Map<String, Object?> toRow() => {
        'at': at.millisecondsSinceEpoch,
        'part': part,
        'organist_id': organistId,
        'place': place,
        'notes': notes,
      };

  static OrganDuty fromRow(Map<String, Object?> r) => OrganDuty(
        id: r['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        part: r['part'] as String,
        organistId: r['organist_id'] as int?,
        place: r['place'] as String? ?? '',
        notes: r['notes'] as String? ?? '',
      );
}

/// Horários do culto num mês (ex.: domingos 18:30 e quintas 19:30).
List<DateTime> monthSlots(int year, int month, List<(int weekday, int hour, int minute)> weekly) {
  final out = <DateTime>[];
  final days = DateTime(year, month + 1, 0).day;
  for (var d = 1; d <= days; d++) {
    final date = DateTime(year, month, d);
    for (final (wd, h, m) in weekly) {
      if (date.weekday == wd) out.add(DateTime(year, month, d, h, m));
    }
  }
  out.sort();
  return out;
}

/// Rodízio: distribui as organistas em ordem pelos cultos.
/// [split] = meia hora e culto com organistas diferentes.
/// Devolve as escalas e o índice da próxima organista (para continuar no mês seguinte).
(List<OrganDuty>, int) generateRotation({
  required List<DateTime> slots,
  required List<int> organistIds,
  required bool split,
  int startIndex = 0,
  String place = '',
}) {
  if (organistIds.isEmpty) return (const [], startIndex);
  var i = startIndex;
  int next() => organistIds[i++ % organistIds.length];
  final out = <OrganDuty>[];
  for (final s in slots) {
    if (split) {
      out.add(OrganDuty(at: s, part: 'Meia hora', organistId: next(), place: place));
      out.add(OrganDuty(at: s, part: 'Culto', organistId: next(), place: place));
    } else {
      out.add(OrganDuty(at: s, part: 'Meia hora e culto', organistId: next(), place: place));
    }
  }
  return (out, i % organistIds.length);
}

class OrganRepository {
  OrganRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organist(
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, is_me INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organ_duty(
        id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, part TEXT NOT NULL,
        organist_id INTEGER, place TEXT, notes TEXT)''');
  }

  Future<List<Organist>> organists() async => [
        for (final r in await _db.query('organist', orderBy: 'position, id'))
          Organist(r['id'] as int, r['name'] as String, r['is_me'] == 1, r['position'] as int),
      ];

  Future<int> addOrganist(String name) async {
    final pos = Sqflite.firstIntValue(await _db.rawQuery('SELECT COALESCE(MAX(position), -1) + 1 FROM organist')) ?? 0;
    return _db.insert('organist', {'name': name.trim(), 'position': pos});
  }

  Future<void> renameOrganist(int id, String name) =>
      _db.update('organist', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);

  Future<void> removeOrganist(int id) async {
    await _db.delete('organist', where: 'id = ?', whereArgs: [id]);
    await _db.update('organ_duty', {'organist_id': null}, where: 'organist_id = ?', whereArgs: [id]);
  }

  /// Marca quem usa o celular (recebe os lembretes da própria escala).
  Future<void> setMe(int? id) async {
    await _db.update('organist', {'is_me': 0});
    if (id != null) await _db.update('organist', {'is_me': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorder(List<int> ids) async {
    final b = _db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('organist', {'position': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
  }

  Future<List<OrganDuty>> duties({DateTime? from, DateTime? to}) async {
    final where = <String>[], args = <Object>[];
    if (from != null) {
      where.add('at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    return [
      for (final r in await _db.query('organ_duty',
          where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'at, part'))
        OrganDuty.fromRow(r),
    ];
  }

  Future<OrganDuty?> duty(int id) async {
    final r = await _db.query('organ_duty', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : OrganDuty.fromRow(r.first);
  }

  Future<int> saveDuty(OrganDuty d) async {
    if (d.id == null) return _db.insert('organ_duty', d.toRow());
    await _db.update('organ_duty', d.toRow(), where: 'id = ?', whereArgs: [d.id]);
    return d.id!;
  }

  Future<void> saveDuties(List<OrganDuty> list) async {
    final b = _db.batch();
    for (final d in list) {
      b.insert('organ_duty', d.toRow());
    }
    await b.commit(noResult: true);
  }

  Future<void> removeDuty(int id) => _db.delete('organ_duty', where: 'id = ?', whereArgs: [id]);

  Future<void> clearMonth(int year, int month) => _db.delete('organ_duty',
      where: 'at >= ? AND at < ?',
      whereArgs: [DateTime(year, month).millisecondsSinceEpoch, DateTime(year, month + 1).millisecondsSinceEpoch]);
}
