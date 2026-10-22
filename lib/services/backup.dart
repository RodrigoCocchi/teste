import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'profile.dart';

/// Dados pessoais copiados no backup (o texto da Bíblia e os hinos não entram:
/// são baixados de novo na instalação).
const Map<String, List<String>> backupTables = {
  'favorite': ['kind', 'ref_key', 'label', 'created_at'],
  'bookmark': ['verse_id', 'color', 'note', 'updated_at'],
  'reading_progress': ['book_id', 'chapter', 'done_at'],
  'saved_place': ['id', 'name', 'code', 'city', 'address', 'detail', 'is_home', 'remind', 'saved_at', 'updated_at'],
  'prayer': ['text', 'created_at', 'answered_at', 'note'],
  'agenda_event': ['id', 'kind', 'title', 'start_at', 'place', 'notes', 'repeat', 'alerts'],
  'organist': ['id', 'name', 'is_me', 'position'],
  'organ_duty': ['id', 'at', 'part', 'organist_id', 'place', 'notes'],
  'rehearsal': ['id', 'at', 'place', 'kind', 'counts', 'notes'],
};

const String backupApp = 'biblia-hinos-ccb';

Future<Map<String, Object?>> buildBackup(Database db, {SharedPreferences? prefs}) async {
  final data = <String, Object?>{};
  for (final e in backupTables.entries) {
    final rows = await db.query(e.key, columns: e.value);
    data[e.key] = rows;
  }
  return {
    'app': backupApp,
    'version': 1,
    'created': DateTime.now().toIso8601String(),
    'data': data,
    if (prefs != null && !Profile.load(prefs).isEmpty) 'profile': Profile.load(prefs).toJson(),
  };
}

String encodeBackup(Map<String, Object?> b) => const JsonEncoder.withIndent(' ').convert(b);

/// Junta o backup aos dados atuais (não apaga nada). Devolve quantos itens entraram.
Future<int> restoreBackup(Database db, String raw, {SharedPreferences? prefs}) async {
  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('Arquivo de backup inválido.');
  }
  if (json is! Map || json['app'] != backupApp || json['data'] is! Map) {
    throw const FormatException('Este arquivo não é um backup do Bíblia & Hinos.');
  }
  final data = json['data'] as Map;
  var count = 0;
  final profile = json['profile'];
  if (prefs != null && profile is Map && Profile.load(prefs).isEmpty) {
    await Profile.fromJson(profile).save(prefs);
    count++;
  }
  await db.transaction((t) async {
    for (final e in backupTables.entries) {
      final rows = data[e.key];
      if (rows is! List) continue;
      for (final r in rows) {
        if (r is! Map) continue;
        final row = {for (final c in e.value) if (r.containsKey(c)) c: r[c]};
        if (e.key == 'prayer') {
          // Sem id: evita duplicar o mesmo pedido.
          final dup = await t.query('prayer',
              where: 'text = ? AND created_at = ?', whereArgs: [row['text'], row['created_at']], limit: 1);
          if (dup.isNotEmpty) continue;
          await t.insert('prayer', row);
        } else if (e.key == 'saved_place' && row['is_home'] == 1) {
          await t.update('saved_place', {'is_home': 0});
          await t.insert(e.key, row, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await t.insert(e.key, row,
              conflictAlgorithm: e.key == 'favorite' ? ConflictAlgorithm.ignore : ConflictAlgorithm.replace);
        }
        count++;
      }
    }
  });
  return count;
}
