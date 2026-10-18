import '../data/bible_books.dart';

/// Referência bíblica: livro, capítulo e (opcionalmente) intervalo de versículos.
class BibleRef {
  const BibleRef(this.bookId, this.chapter, [this.verseStart, this.verseEnd]);

  final int bookId;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;

  BibleBook get book => bookById(bookId);

  int get lastVerse => verseEnd ?? verseStart ?? 0;

  String get label {
    final b = book.name;
    if (verseStart == null) return '$b $chapter';
    if (verseEnd == null || verseEnd == verseStart) {
      return '$b $chapter:$verseStart';
    }
    return '$b $chapter:$verseStart-$verseEnd';
  }

  /// Formato compacto usado nos arquivos JSON: "Gn 6:13-22".
  String get code {
    final b = book.abbrev;
    if (verseStart == null) return '$b $chapter';
    if (verseEnd == null || verseEnd == verseStart) return '$b $chapter:$verseStart';
    return '$b $chapter:$verseStart-$verseEnd';
  }

  bool get isValidChapter => chapter >= 1 && chapter <= book.chapters;

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is BibleRef &&
      other.bookId == bookId &&
      other.chapter == chapter &&
      other.verseStart == verseStart &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(bookId, chapter, verseStart, verseEnd);

  static final RegExp _pattern = RegExp(
    r'^\s*((?:[123]|i{1,3})\s*(?:ª|º)?\.?\s*[a-zà-ÿ][a-zà-ÿ.\s]*?|[a-zà-ÿ][a-zà-ÿ.\s]*?)'
    r'\s*(\d{1,3})?(?:\s*[:.,]\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?)?\s*$',
    caseSensitive: false,
  );

  /// Interpreta textos como "João 3:16", "Jo 3.16-18", "Salmos 23",
  /// "1 Co 13" ou "Gênesis". Retorna null se não for uma referência válida.
  static BibleRef? tryParse(String input) {
    final m = _pattern.firstMatch(input.trim());
    if (m == null) return null;
    final book = findBook(m[1]!.trim());
    if (book == null) return null;
    final chapter = m[2] != null ? int.parse(m[2]!) : 1;
    final vs = m[3] != null ? int.parse(m[3]!) : null;
    var ve = m[4] != null ? int.parse(m[4]!) : null;
    if (chapter < 1 || chapter > book.chapters) return null;
    if (vs != null && vs < 1) return null;
    if (ve != null && vs != null && ve < vs) return null;
    if (ve == vs) ve = null;
    return BibleRef(book.id, chapter, vs, ve);
  }

  /// Aceita apenas o formato com capítulo explícito (para os arquivos JSON).
  static BibleRef parseStrict(String code) {
    final ref = tryParse(code);
    if (ref == null || !RegExp(r'\d').hasMatch(code)) {
      throw FormatException('Referência inválida: $code');
    }
    return ref;
  }
}
