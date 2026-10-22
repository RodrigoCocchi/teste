import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../services/ccb_relatorio.dart';
import 'database.dart';

/// Horário de culto de uma casa de oração (lido de "Dias de Culto").
class CultoTime {
  const CultoTime(this.kind, this.weekday, this.hour, this.minute);
  final String kind; // ex.: Culto Oficial, Reunião de Jovens e Menores
  final int weekday; // DateTime.monday (1) ... DateTime.sunday (7)
  final int hour;
  final int minute;

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  String get dayName => weekdayNames[weekday - 1];

  /// Próxima ocorrência a partir de [now] (inclusive se ainda não começou hoje).
  DateTime nextAfter(DateTime now) {
    var d = DateTime(now.year, now.month, now.day, hour, minute);
    var add = (weekday - now.weekday) % 7;
    d = d.add(Duration(days: add));
    if (!d.isAfter(now)) d = d.add(const Duration(days: 7));
    return d;
  }

  @override
  bool operator ==(Object other) =>
      other is CultoTime &&
      other.kind == kind &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;
  @override
  int get hashCode => Object.hash(kind, weekday, hour, minute);
}

const List<String> weekdayNames = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

const Map<String, int> _days = {
  'segunda': DateTime.monday,
  'terca': DateTime.tuesday,
  'quarta': DateTime.wednesday,
  'quinta': DateTime.thursday,
  'sexta': DateTime.friday,
  'sabado': DateTime.saturday,
  'domingo': DateTime.sunday,
};

/// Lê os horários do bloco "Dias de Culto" do detalhe do relatório.
List<CultoTime> parseCultos(List<RelSection> sections) {
  final out = <CultoTime>[];
  for (final s in sections) {
    if (!_plain(s.title).contains('dias de culto')) continue;
    var kind = 'Culto';
    for (final line in s.lines) {
      final m = RegExp(r'^\s*([A-Za-zÀ-ú]+)(?:-feira)?\s*-\s*(\d{1,2})[:h](\d{2})').firstMatch(line);
      final day = m == null ? null : _days[_plain(m[1]!)];
      if (m != null && day != null) {
        final c = CultoTime(kind, day, int.parse(m[2]!), int.parse(m[3]!));
        if (!out.contains(c)) out.add(c);
      } else if (!RegExp(r'\d').hasMatch(line)) {
        kind = line.trim(); // título do grupo (Culto Oficial, Reunião de Jovens e Menores…)
      }
    }
  }
  out.sort((a, b) => (a.weekday * 1440 + a.hour * 60 + a.minute).compareTo(b.weekday * 1440 + b.hour * 60 + b.minute));
  return out;
}

/// Próximo culto da lista a partir de [now].
(CultoTime, DateTime)? nextCulto(List<CultoTime> times, DateTime now) {
  (CultoTime, DateTime)? best;
  for (final t in times) {
    final d = t.nextAfter(now);
    if (best == null || d.isBefore(best.$2)) best = (t, d);
  }
  return best;
}

/// Casa de oração salva no aparelho (funciona sem internet).
class SavedPlace {
  const SavedPlace({
    required this.place,
    required this.sections,
    this.isHome = false,
    this.remindMinutes,
    required this.updatedAt,
  });
  final RelPlace place;
  final List<RelSection> sections;
  final bool isHome;
  final int? remindMinutes; // null = sem lembrete
  final DateTime updatedAt;

  List<CultoTime> get cultos => parseCultos(sections);
  String get address => [place.address, place.city].where((s) => s.isNotEmpty).join(', ');
  List<String> get phones => [
        for (final s in sections)
          if (_plain(s.title).contains('telefone')) ...s.lines,
      ];
}

class PlacesRepository {
  PlacesRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS saved_place(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, code TEXT, city TEXT, address TEXT,
        detail TEXT NOT NULL, is_home INTEGER NOT NULL DEFAULT 0, remind INTEGER,
        saved_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');

  static String encodeSections(List<RelSection> s) =>
      jsonEncode([for (final x in s) {'t': x.title, 'l': x.lines}]);

  static List<RelSection> decodeSections(String raw) => [
        for (final x in jsonDecode(raw) as List)
          RelSection('${x['t']}', [for (final l in x['l'] as List) '$l']),
      ];

  SavedPlace _row(Map<String, Object?> r) => SavedPlace(
        place: RelPlace(
          id: r['id'] as String,
          name: r['name'] as String,
          code: r['code'] as String? ?? '',
          city: r['city'] as String? ?? '',
          address: r['address'] as String? ?? '',
        ),
        sections: decodeSections(r['detail'] as String),
        isHome: r['is_home'] == 1,
        remindMinutes: r['remind'] as int?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
      );

  Future<List<SavedPlace>> all() async =>
      [for (final r in await _db.query('saved_place', orderBy: 'is_home DESC, name')) _row(r)];

  Future<SavedPlace?> get(String id) async {
    final r = await _db.query('saved_place', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : _row(r.first);
  }

  Future<SavedPlace?> home() async {
    final r = await _db.query('saved_place', where: 'is_home = 1', limit: 1);
    return r.isEmpty ? null : _row(r.first);
  }

  /// Salva (ou atualiza o detalhe, mantendo "minha comum" e lembrete).
  Future<void> save(RelPlace p, List<RelSection> sections) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await _db.update(
      'saved_place',
      {'name': p.name, 'code': p.code, 'city': p.city, 'address': p.address,
        'detail': encodeSections(sections), 'updated_at': now},
      where: 'id = ?',
      whereArgs: [p.id],
    );
    if (updated == 0) {
      await _db.insert('saved_place', {
        'id': p.id, 'name': p.name, 'code': p.code, 'city': p.city, 'address': p.address,
        'detail': encodeSections(sections), 'is_home': 0, 'saved_at': now, 'updated_at': now,
      });
    }
  }

  Future<void> remove(String id) => _db.delete('saved_place', where: 'id = ?', whereArgs: [id]);

  Future<void> setHome(String id, bool home) async {
    await _db.transaction((t) async {
      if (home) await t.update('saved_place', {'is_home': 0});
      await t.update('saved_place', {'is_home': home ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setRemind(String id, int? minutes) =>
      _db.update('saved_place', {'remind': minutes}, where: 'id = ?', whereArgs: [id]);

  /// Linhas cruas, usadas no backup.
  Future<List<Map<String, Object?>>> rawRows() => _db.query('saved_place');
}
