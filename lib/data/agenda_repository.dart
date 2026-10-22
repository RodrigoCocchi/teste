import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Tipos de compromisso da agenda.
class AgendaKind {
  const AgendaKind(this.name, this.icon);
  final String name;
  final IconData icon;
}

const List<AgendaKind> agendaKinds = [
  AgendaKind('Ensaio', Icons.music_note),
  AgendaKind('Santa Ceia', Icons.wine_bar_outlined),
  AgendaKind('Batismo', Icons.water_drop_outlined),
  AgendaKind('Culto', Icons.event),
  AgendaKind('Reunião de Jovens e Menores', Icons.groups_outlined),
  AgendaKind('Reunião', Icons.forum_outlined),
  AgendaKind('Outro', Icons.event_note),
];

IconData agendaIcon(String kind) =>
    agendaKinds.where((k) => k.name == kind).firstOrNull?.icon ?? Icons.event_note;

/// Antecedências oferecidas para os alertas (minutos).
const Map<int, String> alertOptions = {
  10: '10 min',
  30: '30 min',
  60: '1 hora',
  120: '2 horas',
  1440: '1 dia',
  2880: '2 dias',
  10080: '1 semana',
};

String alertsLabel(List<int> alerts) =>
    alerts.isEmpty ? 'Sem alerta' : (alerts.toList()..sort()).map((m) => alertOptions[m] ?? '$m min').join(', ');

/// Repetição: nenhuma, semanal ou mensal (mesmo dia do mês).
const Map<String, String> repeatOptions = {'none': 'Não repete', 'weekly': 'Toda semana', 'monthly': 'Todo mês'};

class AgendaEvent {
  const AgendaEvent({
    this.id,
    required this.kind,
    this.title = '',
    required this.start,
    this.place = '',
    this.notes = '',
    this.repeat = 'none',
    this.alerts = const [60],
  });
  final int? id;
  final String kind;
  final String title; // opcional: "Ensaio regional", "Batismo na comum Brás"…
  final DateTime start;
  final String place;
  final String notes;
  final String repeat;
  final List<int> alerts;

  String get displayTitle => title.trim().isEmpty ? kind : title.trim();

  /// Próxima ocorrência a partir de [now] (null se já passou e não repete).
  DateTime? nextAfter(DateTime now) {
    if (!start.isBefore(now)) return start;
    switch (repeat) {
      case 'weekly':
        final weeks = (now.difference(start).inMinutes / (7 * 1440)).ceil();
        var d = DateTime(start.year, start.month, start.day + 7 * weeks, start.hour, start.minute);
        if (d.isBefore(now)) d = DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
        return d;
      case 'monthly':
        var m = (now.year - start.year) * 12 + now.month - start.month;
        for (var i = 0; i < 3; i++, m++) {
          final y = start.year + (start.month - 1 + m) ~/ 12;
          final mo = (start.month - 1 + m) % 12 + 1;
          final last = DateTime(y, mo + 1, 0).day;
          final d = DateTime(y, mo, start.day > last ? last : start.day, start.hour, start.minute);
          if (!d.isBefore(now)) return d;
        }
        return null;
      default:
        return null;
    }
  }

  AgendaEvent copyWith({int? id}) => AgendaEvent(
      id: id ?? this.id, kind: kind, title: title, start: start, place: place, notes: notes, repeat: repeat, alerts: alerts);

  Map<String, Object?> toRow() => {
        'kind': kind,
        'title': title,
        'start_at': start.millisecondsSinceEpoch,
        'place': place,
        'notes': notes,
        'repeat': repeat,
        'alerts': jsonEncode(alerts),
      };

  static AgendaEvent fromRow(Map<String, Object?> r) => AgendaEvent(
        id: r['id'] as int,
        kind: r['kind'] as String,
        title: r['title'] as String? ?? '',
        start: DateTime.fromMillisecondsSinceEpoch(r['start_at'] as int),
        place: r['place'] as String? ?? '',
        notes: r['notes'] as String? ?? '',
        repeat: r['repeat'] as String? ?? 'none',
        alerts: [for (final a in jsonDecode(r['alerts'] as String? ?? '[]') as List) a as int],
      );
}

class AgendaRepository {
  AgendaRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS agenda_event(
        id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT, start_at INTEGER NOT NULL,
        place TEXT, notes TEXT, repeat TEXT NOT NULL DEFAULT 'none', alerts TEXT NOT NULL DEFAULT '[]')''');

  Future<List<AgendaEvent>> all() async =>
      [for (final r in await _db.query('agenda_event', orderBy: 'start_at')) AgendaEvent.fromRow(r)];

  Future<AgendaEvent?> get(int id) async {
    final r = await _db.query('agenda_event', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : AgendaEvent.fromRow(r.first);
  }

  Future<int> save(AgendaEvent e) async {
    if (e.id == null) return _db.insert('agenda_event', e.toRow());
    await _db.update('agenda_event', e.toRow(), where: 'id = ?', whereArgs: [e.id]);
    return e.id!;
  }

  Future<void> remove(int id) => _db.delete('agenda_event', where: 'id = ?', whereArgs: [id]);
}
