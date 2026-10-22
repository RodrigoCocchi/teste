import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Grupo da contagem (naipe ou categoria) e seus itens.
class CountGroup {
  const CountGroup(this.name, this.items, {this.musicians = false});
  final String name;
  final List<String> items;
  final bool musicians; // entra no total de músicos

  Map<String, Object?> toJson() => {'n': name, 'i': items, 'm': musicians};
  static CountGroup fromJson(Map<String, dynamic> j) =>
      CountGroup('${j['n']}', [for (final i in j['i'] as List) '$i'], musicians: j['m'] == true);
}

/// Lista padrão (pode ser editada no app).
const List<CountGroup> defaultCountGroups = [
  CountGroup('Cordas', ['Violino', 'Viola', 'Violoncelo'], musicians: true),
  CountGroup('Madeiras', [
    'Flauta', 'Oboé', "Oboé d'amore", 'Corne inglês', 'Fagote', 'Clarinete', 'Clarinete alto', 'Clarone',
    'Sax soprano', 'Sax alto', 'Sax tenor', 'Sax barítono',
  ], musicians: true),
  CountGroup('Metais', ['Trompete', 'Flugelhorn', 'Trompa', 'Trombone', 'Trombonito', 'Eufônio', 'Tuba'], musicians: true),
  CountGroup('Órgão', ['Organistas']),
  CountGroup('Outros', ['Alunos do GEM', 'Encarregados regionais', 'Encarregados locais', 'Instrutores', 'Visitas']),
];

String encodeGroups(List<CountGroup> g) => jsonEncode([for (final x in g) x.toJson()]);
List<CountGroup> decodeGroups(String raw) =>
    [for (final x in jsonDecode(raw) as List) CountGroup.fromJson(x as Map<String, dynamic>)];

/// Somas da contagem.
class CountTotals {
  const CountTotals(this.byGroup, this.musicians, this.organists, this.total);
  final Map<String, int> byGroup;
  final int musicians;
  final int organists;
  final int total;
}

CountTotals totalsOf(List<CountGroup> groups, Map<String, int> counts) {
  final by = <String, int>{};
  var musicians = 0, organists = 0, total = 0;
  for (final g in groups) {
    var s = 0;
    for (final i in g.items) {
      s += counts[i] ?? 0;
    }
    by[g.name] = s;
    total += s;
    if (g.musicians) musicians += s;
    for (final i in g.items) {
      if (i.toLowerCase().startsWith('organista')) organists += counts[i] ?? 0;
    }
  }
  return CountTotals(by, musicians, organists, total);
}

class Rehearsal {
  const Rehearsal({this.id, required this.at, this.place = '', this.kind = 'Ensaio local', this.counts = const {}, this.notes = ''});
  final int? id;
  final DateTime at;
  final String place;
  final String kind;
  final Map<String, int> counts;
  final String notes;

  Map<String, Object?> toRow() => {
        'at': at.millisecondsSinceEpoch,
        'place': place,
        'kind': kind,
        'counts': jsonEncode(counts),
        'notes': notes,
      };

  static Rehearsal fromRow(Map<String, Object?> r) => Rehearsal(
        id: r['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        place: r['place'] as String? ?? '',
        kind: r['kind'] as String? ?? 'Ensaio local',
        counts: {
          for (final e in (jsonDecode(r['counts'] as String? ?? '{}') as Map).entries) '${e.key}': (e.value as num).toInt(),
        },
        notes: r['notes'] as String? ?? '',
      );
}

const List<String> rehearsalKinds = ['Ensaio local', 'Ensaio regional', 'Ensaio de jovens', 'Outro'];

class RehearsalRepository {
  RehearsalRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS rehearsal(
        id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, place TEXT, kind TEXT,
        counts TEXT NOT NULL DEFAULT '{}', notes TEXT)''');

  Future<List<Rehearsal>> all() async =>
      [for (final r in await _db.query('rehearsal', orderBy: 'at DESC')) Rehearsal.fromRow(r)];

  Future<int> save(Rehearsal r) async {
    if (r.id == null) return _db.insert('rehearsal', r.toRow());
    await _db.update('rehearsal', r.toRow(), where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> remove(int id) => _db.delete('rehearsal', where: 'id = ?', whereArgs: [id]);
}
