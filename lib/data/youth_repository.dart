import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Situação do recitativo.
const Map<String, String> recitStatus = {'decorar': 'A decorar', 'pronto': 'Pronto', 'recitado': 'Recitado'};

/// Recitativo guardado (texto copiado da Bíblia do app no momento em que foi salvo).
class Recitativo {
  const Recitativo({this.id, this.person = '', required this.ref, this.text = '', this.status = 'decorar', this.recitedAt, this.notes = ''});
  final int? id;
  final String person;
  final String ref; // ex.: Salmos 23:1-3
  final String text;
  final String status;
  final DateTime? recitedAt;
  final String notes;

  Map<String, Object?> toRow() => {
        'person': person,
        'ref': ref,
        'text': text,
        'status': status,
        'recited_at': recitedAt?.millisecondsSinceEpoch,
        'notes': notes,
      };

  static Recitativo fromRow(Map<String, Object?> r) => Recitativo(
        id: r['id'] as int,
        person: r['person'] as String? ?? '',
        ref: r['ref'] as String,
        text: r['text'] as String? ?? '',
        status: r['status'] as String? ?? 'decorar',
        recitedAt: r['recited_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['recited_at'] as int),
        notes: r['notes'] as String? ?? '',
      );
}

/// Modo de treino: mostra só a primeira letra de cada palavra.
String firstLetters(String text) => text.replaceAllMapped(
    RegExp(r'([A-Za-zÀ-ÿ])([A-Za-zÀ-ÿ]*)'), (m) => '${m[1]}${'_' * (m[2]!.length.clamp(0, 6))}');

/// Passo do roteiro da reunião.
class RjmStep {
  RjmStep(this.title, {this.detail = '', this.done = false});
  String title;
  String detail; // ex.: número do hino, quem vai orar
  bool done;

  Map<String, Object?> toJson() => {'t': title, 'd': detail, 'x': done};
  static RjmStep fromJson(Map j) => RjmStep('${j['t']}', detail: '${j['d'] ?? ''}', done: j['x'] == true);

  /// Número do hino, se o detalhe for um hino (ex.: "Hino 120").
  int? get hymnNumber {
    if (!title.toLowerCase().contains('hino')) return null;
    return int.tryParse(RegExp(r'\d{1,3}').firstMatch(detail)?[0] ?? '');
  }
}

/// Recitativo na fila da reunião.
class RjmRecit {
  RjmRecit(this.person, this.ref, {this.done = false});
  String person;
  String ref;
  bool done;

  Map<String, Object?> toJson() => {'p': person, 'r': ref, 'x': done};
  static RjmRecit fromJson(Map j) => RjmRecit('${j['p'] ?? ''}', '${j['r'] ?? ''}', done: j['x'] == true);
}

/// Modelo inicial do roteiro: apenas um exemplo, editável conforme a orientação da comum.
const List<String> defaultRjmTemplate = [
  'Hino',
  'Oração',
  'Hino',
  'Recitativos',
  'Hino',
  'Palavra',
  'Hino',
  'Oração final',
];

/// Uma reunião acompanhada pelo auxiliar.
class RjmSession {
  RjmSession({this.id, required this.at, this.place = '', required this.steps, List<RjmRecit>? recits, this.notes = '', this.startedAt})
      : recits = recits ?? [];
  int? id;
  DateTime at;
  String place;
  List<RjmStep> steps;
  List<RjmRecit> recits;
  String notes;
  DateTime? startedAt;

  int get done => steps.where((s) => s.done).length;

  Map<String, Object?> toRow() => {
        'at': at.millisecondsSinceEpoch,
        'place': place,
        'steps': jsonEncode([for (final s in steps) s.toJson()]),
        'recits': jsonEncode([for (final r in recits) r.toJson()]),
        'notes': notes,
        'started_at': startedAt?.millisecondsSinceEpoch,
      };

  static RjmSession fromRow(Map<String, Object?> r) => RjmSession(
        id: r['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        place: r['place'] as String? ?? '',
        steps: [for (final s in jsonDecode(r['steps'] as String? ?? '[]') as List) RjmStep.fromJson(s as Map)],
        recits: [for (final s in jsonDecode(r['recits'] as String? ?? '[]') as List) RjmRecit.fromJson(s as Map)],
        notes: r['notes'] as String? ?? '',
        startedAt: r['started_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
      );
}

class YouthRepository {
  YouthRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recitativo(
        id INTEGER PRIMARY KEY AUTOINCREMENT, person TEXT, ref TEXT NOT NULL, text TEXT,
        status TEXT NOT NULL DEFAULT 'decorar', recited_at INTEGER, notes TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rjm_session(
        id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, place TEXT, steps TEXT NOT NULL,
        recits TEXT NOT NULL DEFAULT '[]', notes TEXT, started_at INTEGER)''');
  }

  Future<List<Recitativo>> recitativos() async =>
      [for (final r in await _db.query('recitativo', orderBy: "CASE status WHEN 'decorar' THEN 0 WHEN 'pronto' THEN 1 ELSE 2 END, id DESC")) Recitativo.fromRow(r)];

  Future<int> saveRecitativo(Recitativo r) async {
    if (r.id == null) return _db.insert('recitativo', r.toRow());
    await _db.update('recitativo', r.toRow(), where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> removeRecitativo(int id) => _db.delete('recitativo', where: 'id = ?', whereArgs: [id]);

  Future<List<RjmSession>> sessions() async =>
      [for (final r in await _db.query('rjm_session', orderBy: 'at DESC')) RjmSession.fromRow(r)];

  Future<int> saveSession(RjmSession s) async {
    if (s.id == null) return s.id = await _db.insert('rjm_session', s.toRow());
    await _db.update('rjm_session', s.toRow(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  Future<void> removeSession(int id) => _db.delete('rjm_session', where: 'id = ?', whereArgs: [id]);
}
