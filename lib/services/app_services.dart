import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/bible_books.dart';
import '../data/bible_repository.dart';
import '../data/content.dart';
import '../data/database.dart';
import '../data/hymn_repository.dart';
import '../data/plan_repository.dart';
import '../data/quiz_repository.dart';
import '../data/user_repository.dart';
import 'bible_parser.dart';
import 'documents.dart';
import 'settings.dart';

/// Ponto único de acesso aos serviços (inicializado em main()).
class App {
  App._(this.db, this.settings, this.documents, this.questions, this.themes, this.studies);

  static late App I;

  final AppDatabase db;
  final Settings settings;
  final DocumentStore documents;
  final List<QuizQuestion> questions;
  final List<BibleThemeData> themes;
  final List<DailyStudyData> studies;

  late final bible = BibleRepository(db);
  late final user = UserRepository(db);
  late final quiz = QuizRepository(db);
  late final hymns = HymnRepository(db);
  late final plan = PlanRepository(db);

  /// Incrementado quando o texto bíblico muda (nova importação).
  final ValueNotifier<int> bibleVersion = ValueNotifier(0);
  int verseCount = 0;
  bool get hasBibleText => verseCount > 0;

  static Future<App> init({AssetBundle? bundle, String? dbPath, DatabaseFactory? factory,
      SharedPreferences? prefs, String? dataDir}) async {
    final b = bundle ?? rootBundle;
    final dir = dataDir ?? await _dataDir();
    final sp = prefs ?? await SharedPreferences.getInstance();
    final db = await AppDatabase.open(dbPath ?? p.join(dir, 'biblia_hinos.db'), factory: factory);
    final app = App._(
      db,
      Settings(sp),
      DocumentStore(sp, dir),
      QuizQuestion.listFromJson(await b.loadString('assets/data/quiz.json')),
      BibleThemeData.listFromJson(await b.loadString('assets/data/themes.json')),
      DailyStudyData.listFromJson(await b.loadString('assets/data/studies.json')),
    );
    I = app;
    await app._seed();
    app.verseCount = await app.bible.verseCount();
    return app;
  }

  /// Pasta privada do app; se o path_provider falhar, usa a pasta do sqflite.
  static Future<String> _dataDir() async {
    try {
      return (await getApplicationDocumentsDirectory()).path;
    } on Object {
      return getDatabasesPath();
    }
  }

  Future<void> _seed() async {
    await quiz.seed(questions);
    await hymns.seed();
    await plan.seed();
    final d = db.db;
    final batch = d.batch()
      ..delete('theme_reference')
      ..delete('bible_theme')
      ..delete('daily_study');
    for (final t in themes) {
      batch.insert('bible_theme', {'id': t.id, 'name': t.name, 'description': t.description});
      for (var i = 0; i < t.refs.length; i++) {
        final r = t.refs[i];
        batch.insert('theme_reference', {
          'theme_id': t.id,
          'book_id': r.bookId,
          'chapter': r.chapter,
          'verse_start': r.verseStart ?? 1,
          'verse_end': r.verseEnd,
          'position': i,
        });
      }
    }
    for (final s in studies) {
      batch.insert('daily_study', {
        'id': s.id,
        'day': s.id,
        'title': s.title,
        'theme': s.theme,
        'refs': jsonEncode(s.refs.map((r) => r.code).toList()),
        'context': s.context,
        'reflection': s.reflection,
        'questions': jsonEncode(s.questions),
      });
    }
    await batch.commit(noResult: true);
  }

  /// Grava o resultado da estruturação e confere as perguntas do quiz.
  Future<String> storeBible(BibleParseResult r, String source,
      {void Function(double)? onProgress}) async {
    await bible.replaceAll(r, onProgress: onProgress);
    verseCount = await bible.verseCount();
    final check = await quiz.verifyAgainstBible(questions, bible);
    final report = '${r.summary()}'
        'Perguntas do quiz conferidas com o texto: ${check['conferida']}, '
        'divergentes: ${check['divergente']}, sem texto: ${check['pendente']}';
    settings.bibleSource = source;
    settings.bibleReport = report;
    bibleVersion.value++;
    return report;
  }

  /// Importa texto já estruturado em JSON. Formatos aceitos:
  /// {"verses":[{"b":1,"c":1,"v":1,"t":"..."}]} ou
  /// [{"abbrev":"gn","chapters":[["v1","v2"], ...]}, ...] (66 livros em ordem).
  static BibleParseResult parseBibleJson(String source) {
    final data = jsonDecode(source.replaceFirst('﻿', ''));
    final verses = <ParsedVerse>[];
    if (data is Map && data['verses'] is List) {
      for (final v in data['verses'] as List) {
        final b = v['b'] as int, c = v['c'] as int, n = v['v'] as int;
        if (b < 1 || b > 66 || c < 1 || c > bookById(b).chapters || n < 1) continue;
        verses.add(ParsedVerse(b, c, n, (v['t'] as String).trim(), 0));
      }
    } else if (data is List && data.length == 66) {
      for (var i = 0; i < 66; i++) {
        final chapters = data[i]['chapters'] as List;
        for (var c = 0; c < chapters.length && c < bookById(i + 1).chapters; c++) {
          final vs = chapters[c] as List;
          for (var v = 0; v < vs.length; v++) {
            verses.add(ParsedVerse(i + 1, c + 1, v + 1, (vs[v] as String).trim(), 0));
          }
        }
      }
    } else {
      throw const FormatException('Formato JSON não reconhecido.');
    }
    verses.sort((a, b) => (a.book * 1000000 + a.chapter * 1000 + a.verse)
        .compareTo(b.book * 1000000 + b.chapter * 1000 + b.verse));
    return BibleParseResult(verses, {}, {});
  }

  /// Exporta o texto estruturado para conferência externa.
  Future<File> exportBibleJson(String dir) async {
    final rows = await db.db.query('bible_verse', orderBy: 'id');
    final f = File(p.join(dir, 'biblia_estruturada.json'));
    await f.writeAsString(jsonEncode({
      'source': settings.bibleSource,
      'verses': [
        for (final r in rows) {'b': r['book_id'], 'c': r['chapter'], 'v': r['verse'], 't': r['text']},
      ],
    }));
    return f;
  }
}
