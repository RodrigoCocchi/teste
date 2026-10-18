import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hymn_repository.dart';

enum ReadingTheme { light, dark, sepia }

/// Preferências persistentes (shared_preferences).
class Settings extends ChangeNotifier {
  Settings(this._prefs);
  final SharedPreferences _prefs;

  ReadingTheme get theme =>
      ReadingTheme.values[(_prefs.getInt('theme') ?? 0).clamp(0, ReadingTheme.values.length - 1)];
  set theme(ReadingTheme t) {
    _prefs.setInt('theme', t.index);
    notifyListeners();
  }

  double get fontSize => _prefs.getDouble('fontSize') ?? 19;
  set fontSize(double v) {
    _prefs.setDouble('fontSize', v.clamp(13, 34));
    notifyListeners();
  }

  /// Último capítulo lido: (livro, capítulo).
  (int, int)? get lastChapter {
    final b = _prefs.getInt('lastBook');
    final c = _prefs.getInt('lastChapter');
    return b == null || c == null ? null : (b, c);
  }

  void setLastChapter(int book, int chapter) {
    _prefs.setInt('lastBook', book);
    _prefs.setInt('lastChapter', chapter);
    notifyListeners();
  }

  int? get lastHymn => _prefs.getInt('lastHymn');
  set lastHymn(int? n) {
    if (n == null) {
      _prefs.remove('lastHymn');
    } else {
      _prefs.setInt('lastHymn', n);
    }
    notifyListeners();
  }

  /// Hinário preferido: 'do' ou 'orgao'.
  String get hymnDoc => _prefs.getString('hymnDoc') ?? 'do';
  set hymnDoc(String d) {
    _prefs.setString('hymnDoc', d);
    notifyListeners();
  }

  LinearMapping? linearMapping(String doc) {
    final first = _prefs.getInt('map_${doc}_first');
    if (first == null) return null;
    return LinearMapping(first, _prefs.getInt('map_${doc}_pph') ?? 1,
        _prefs.getInt('map_${doc}_choir'));
  }

  void setLinearMapping(String doc, LinearMapping? m) {
    if (m == null) {
      _prefs.remove('map_${doc}_first');
      _prefs.remove('map_${doc}_pph');
      _prefs.remove('map_${doc}_choir');
    } else {
      _prefs.setInt('map_${doc}_first', m.firstPage);
      _prefs.setInt('map_${doc}_pph', m.pagesPerHymn);
      if (m.choirFirstPage == null) {
        _prefs.remove('map_${doc}_choir');
      } else {
        _prefs.setInt('map_${doc}_choir', m.choirFirstPage!);
      }
    }
    notifyListeners();
  }

  /// Última página aberta em cada PDF.
  int pdfPage(String doc) => _prefs.getInt('pdfPage_$doc') ?? 1;
  void setPdfPage(String doc, int page) => _prefs.setInt('pdfPage_$doc', page);

  /// Respostas pessoais do Estudo do Dia.
  String studyAnswer(int study, int q) => _prefs.getString('study_${study}_$q') ?? '';
  void setStudyAnswer(int study, int q, String v) => _prefs.setString('study_${study}_$q', v);

  String? get bibleSource => _prefs.getString('bibleSource');
  set bibleSource(String? v) {
    if (v == null) {
      _prefs.remove('bibleSource');
    } else {
      _prefs.setString('bibleSource', v);
    }
    notifyListeners();
  }

  String? get bibleReport => _prefs.getString('bibleReport');
  set bibleReport(String? v) {
    if (v == null) {
      _prefs.remove('bibleReport');
    } else {
      _prefs.setString('bibleReport', v);
    }
    notifyListeners();
  }

  void touch() => notifyListeners();
}
