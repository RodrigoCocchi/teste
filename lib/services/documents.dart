import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Documentos PDF importados pelo usuário (não acompanham o APK).
enum DocKind {
  bible('bible', 'Bíblia ARC 1969'),
  hymnalDo('do', 'Hinário 5 — em Dó'),
  hymnalOrgao('orgao', 'Hinário 5 — para órgão'),
  hymnalCanto('canto', 'Hinário 5 — só canto');

  const DocKind(this.key, this.label);
  final String key;
  final String label;

  static DocKind hymnal(String doc) => switch (doc) { 'orgao' => hymnalOrgao, 'canto' => hymnalCanto, _ => hymnalDo };
}

class DocInfo {
  const DocInfo(this.kind, this.path, this.originalName, this.size, this.importedAt);
  final DocKind kind;
  final String path;
  final String originalName;
  final int size;
  final DateTime importedAt;

  String get sizeLabel => '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class DocumentStore extends ChangeNotifier {
  DocumentStore(this._prefs, this._dir);
  final SharedPreferences _prefs;
  final String _dir;

  DocInfo? info(DocKind kind) {
    final name = _prefs.getString('doc_${kind.key}_name');
    final path = p.join(_dir, 'documents', '${kind.key}.pdf');
    if (name == null || !File(path).existsSync()) return null;
    return DocInfo(
      kind,
      path,
      name,
      _prefs.getInt('doc_${kind.key}_size') ?? 0,
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt('doc_${kind.key}_at') ?? 0),
    );
  }

  bool has(DocKind kind) => info(kind) != null;

  /// Copia o arquivo escolhido para a pasta privada do app, validando que é PDF.
  Future<DocInfo> import(DocKind kind, String sourcePath, String originalName) async {
    final src = File(sourcePath);
    final raf = await src.open();
    final header = String.fromCharCodes(await raf.read(5));
    await raf.close();
    if (header != '%PDF-') {
      throw const FormatException('O arquivo escolhido não é um PDF válido.');
    }
    final dest = File(p.join(_dir, 'documents', '${kind.key}.pdf'));
    await dest.parent.create(recursive: true);
    final tmp = File('${dest.path}.tmp');
    await src.copy(tmp.path);
    await tmp.rename(dest.path);
    final size = await dest.length();
    await _prefs.setString('doc_${kind.key}_name', originalName);
    await _prefs.setInt('doc_${kind.key}_size', size);
    await _prefs.setInt('doc_${kind.key}_at', DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
    return info(kind)!;
  }

  Future<void> remove(DocKind kind) async {
    final f = File(p.join(_dir, 'documents', '${kind.key}.pdf'));
    if (await f.exists()) await f.delete();
    await _prefs.remove('doc_${kind.key}_name');
    notifyListeners();
  }

  String get audioDir => p.join(_dir, 'audio');
}
