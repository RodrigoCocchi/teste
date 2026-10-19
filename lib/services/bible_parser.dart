import '../core/text_utils.dart';
import '../data/bible_books.dart';

/// Versículo extraído do texto do PDF.
class ParsedVerse {
  ParsedVerse(this.book, this.chapter, this.verse, this.text, this.page);
  final int book;
  final int chapter;
  final int verse;
  String text;
  final int page;
}

/// Resultado da estruturação do texto da Bíblia.
class BibleParseResult {
  BibleParseResult(this.verses, this.chapterPages, this.bookPages);

  final List<ParsedVerse> verses;

  /// Chave book*1000+chapter → página (1-based) onde o capítulo começa.
  final Map<int, int> chapterPages;

  /// Livro → página (1-based) onde começa.
  final Map<int, int> bookPages;

  /// Capítulos com problemas detectados (chave book*1000+chapter).
  final Set<int> suspectChapters = {};

  Set<int> get parsedChapters => {for (final v in verses) v.book * 1000 + v.chapter};

  List<int> get missingChapters {
    final have = parsedChapters;
    return [
      for (final b in bibleBooks)
        for (var c = 1; c <= b.chapters; c++)
          if (!have.contains(b.id * 1000 + c)) b.id * 1000 + c,
    ];
  }

  bool get isComplete => missingChapters.isEmpty;

  String summary() {
    final missing = missingChapters;
    final books = {for (final v in verses) v.book}.length;
    final sb = StringBuffer()
      ..writeln('Versículos extraídos: ${verses.length}')
      ..writeln('Livros encontrados: $books de 66')
      ..writeln('Capítulos estruturados: ${parsedChapters.length} de $totalBibleChapters')
      ..writeln('Capítulos ausentes: ${missing.length}')
      ..writeln('Capítulos a conferir: ${suspectChapters.length}');
    if (missing.isNotEmpty) {
      final first = missing.take(10).map(_label).join(', ');
      sb.writeln('Primeiros ausentes: $first${missing.length > 10 ? '…' : ''}');
    }
    return sb.toString();
  }

  static String _label(int key) => '${bookById(key ~/ 1000).abbrev} ${key % 1000}';
}

enum _TokType { text, number, title }

/// [verseStart]: número pequeno no início da linha (layout ARC).
enum _NumKind { inline, lone, chapterHint, verseStart }

class _Tok {
  _Tok.text(this.text, this.page)
      : type = _TokType.text,
        n = 0,
        kind = _NumKind.inline;
  _Tok.title(this.text, this.page)
      : type = _TokType.title,
        n = 0,
        kind = _NumKind.inline;
  _Tok.number(this.n, this.kind, this.page, this.text) : type = _TokType.number;

  final _TokType type;
  final String text;
  final int n;
  final _NumKind kind;
  final int page;
}

final RegExp _loneNumber = RegExp(r'^\d{1,3}$');
final RegExp _chapterHint =
    RegExp(r'^(?:cap[ií]tulo|salmo)\s+(\d{1,3})\.?$', caseSensitive: false);
final RegExp _inlineNumber =
    RegExp(r'(?<![\w\d])(\d{1,3})(?=\s?["“«(¶]?[A-Za-zÀ-ÿ])');
final RegExp _upperLetters = RegExp(r'[A-ZÀ-Þ]');
final RegExp _lowerLetters = RegExp(r'[a-zß-ÿ]');

final Set<String> _bookKeys = {
  for (final b in bibleBooks) ...[
    normalize(b.name).replaceAll(RegExp(r'[^a-z]'), ''),
    for (final a in b.aliases) a.replaceAll(RegExp(r'[^a-z]'), ''),
  ],
};

/// Cabeçalho de página: nome do livro + números (ex.: "GÊNESIS 1, 2").
bool _isRunningHeader(String line) {
  if (line.length > 60 || !RegExp(r'\d').hasMatch(line)) return false;
  final letters = normalize(line)
      .replaceAll(RegExp(r'cap[ií]tulos?|salmos?'), '')
      .replaceAll(RegExp(r'[^a-z]'), '');
  if (letters.isEmpty) return true; // apenas números/pontuação
  return _bookKeys.contains(letters);
}

/// Linha em caixa alta (títulos de livro/capítulo).
bool _isTitleLine(String line) {
  final upper = _upperLetters.allMatches(line).length;
  final lower = _lowerLetters.allMatches(line).length;
  return upper >= 4 && lower == 0 && line.length <= 90;
}

const Set<String> _enclitics = {
  'o', 'a', 'os', 'as', 'lo', 'la', 'los', 'las', 'no', 'na', 'nos', 'nas',
  'lhe', 'lhes', 'me', 'te', 'se', 'vos', 'ei', 'emos', 'eis', 'ao', 'ão',
  'ia', 'ias', 'iam', 'á', 'ás', 'hei',
};

/// Converte as linhas de cada página (já em ordem de leitura) em tokens.
/// Como tratar números no meio das linhas:
/// [all] qualquer número pode ser versículo; [lineStart] só no início da
/// linha; [dropSmall] ignora números em fonte menor (chamadas de notas).
/// [smallStart]: versículos são números em fonte menor no início da linha
/// (layout da ARC 1969 da cemaad), demais números pequenos são notas.
enum _Mode { smallStart, all, lineStart, dropSmall }

final RegExp _footnoteLine =
    RegExp('^(?:$smallMark?\\d{1,2}\\s*$smallMark?|[a-z])\\s+\\d{1,3}[.:]\\d{1,3}');
final RegExp _smallStart = RegExp('^$smallMark(\\d{1,3})\\s*');
final RegExp _bookChapterLine = RegExp(r'^([1-3]?\s?[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ ]*?)\s+(\d{1,3})$');

bool _isBookName(String s) =>
    _bookKeys.contains(normalize(s).replaceAll(RegExp(r'[^a-z]'), ''));
final RegExp _smallNumber = RegExp('$smallMark\\d+');

List<_Tok> _tokenize(List<List<String>> pages, [_Mode mode = _Mode.all]) {
  final toks = <_Tok>[];
  final pageNumbers = _detectPageNumbers(pages);
  for (var p = 0; p < pages.length; p++) {
    final page = p + 1;
    final lines = pages[p];
    for (var li = 0; li < lines.length; li++) {
      final raw = lines[li];
      if (_footnoteLine.hasMatch(raw.trim())) continue; // notas/referências cruzadas
      if (mode == _Mode.smallStart) {
        _tokenizeSmallStart(raw.trim(), page, lines, li, toks);
        continue;
      }
      final line = (mode == _Mode.all
              ? raw.replaceAll(smallMark, '')
              : raw.replaceAll(_smallNumber, '').replaceAll(smallMark, ''))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.isEmpty) continue;
      if (pageNumbers != null) {
        final (pos, offset) = pageNumbers;
        final at = pos >= 0 ? pos : lines.length + pos;
        if (li == at && line == '${page + offset}') continue; // nº da página
      }
      if (_loneNumber.hasMatch(line)) {
        toks.add(_Tok.number(int.parse(line), _NumKind.lone, page, line));
        continue;
      }
      final hint = _chapterHint.firstMatch(line);
      if (hint != null) {
        toks.add(_Tok.number(int.parse(hint[1]!), _NumKind.chapterHint, page, line));
        continue;
      }
      if (_isRunningHeader(line)) continue;
      if (_isTitleLine(line)) {
        toks.add(_Tok.title(line, page));
        continue;
      }
      var last = 0;
      for (final m in _inlineNumber.allMatches(line)) {
        if (mode == _Mode.lineStart && m.start > 0) continue;
        if (m.start > last) toks.add(_Tok.text(line.substring(last, m.start), page));
        toks.add(_Tok.number(int.parse(m[1]!), _NumKind.inline, page, m[1]!));
        last = m.end;
      }
      if (last < line.length) toks.add(_Tok.text(line.substring(last), page));
      toks.add(_Tok.text('\n', page)); // quebra de linha (para hifenização)
    }
  }
  return toks;
}

/// Linha no layout "número pequeno no início = versículo".
void _tokenizeSmallStart(String raw, int page, List<String> lines, int li, List<_Tok> toks) {
  final bc = _bookChapterLine.firstMatch(raw.replaceAll(smallMark, '').trim());
  if (bc != null && _isBookName(bc[1]!)) {
    toks.add(_Tok.number(int.parse(bc[2]!), _NumKind.chapterHint, page, raw));
    return;
  }
  final m = _smallStart.firstMatch(raw);
  var rest = (m == null ? raw : raw.substring(m.end)).replaceAll(_smallNumber, '').replaceAll(smallMark, '');
  rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (m == null) {
    if (_loneNumber.hasMatch(rest)) {
      toks.add(_Tok.number(int.parse(rest), _NumKind.lone, page, rest));
      return;
    }
    if (rest.isEmpty || _isRunningHeader(rest)) return;
    if (_isTitleLine(rest) || _isSectionHeading(rest, lines, li)) {
      toks.add(_Tok.title(rest, page));
      return;
    }
  } else {
    toks.add(_Tok.number(int.parse(m[1]!), _NumKind.verseStart, page, m[1]!));
  }
  if (rest.isNotEmpty) toks.add(_Tok.text(rest, page));
  toks.add(_Tok.text('\n', page));
}

/// Título de seção: linha curta, sem pontuação final, depois de uma linha
/// que terminou frase (ou de cabeçalho/nota).
bool _isSectionHeading(String line, List<String> lines, int li) {
  if (RegExp(r'[.,;:!?)»"”]$').hasMatch(line)) return false;
  final lengths = [for (final l in lines) l.length]..sort();
  final full = lengths.isEmpty ? 0 : lengths[(lengths.length * 3) ~/ 4];
  if (line.length > full * 0.7) return false;
  if (li == 0) return true;
  final prev = lines[li - 1].replaceAll(_smallNumber, '').trim();
  return RegExp(r'[.;:!?»"”]$').hasMatch(prev) ||
      _footnoteLine.hasMatch(lines[li - 1].trim()) ||
      _bookChapterLine.hasMatch(prev);
}

/// Detecta a numeração impressa das páginas (número isolado sempre na mesma
/// posição, no topo ou no rodapé) como deslocamento constante em relação ao
/// índice da página. Retorna (posição da linha, deslocamento); posições
/// negativas contam a partir do fim da página.
(int, int)? _detectPageNumbers(List<List<String>> pages) {
  final counts = <(int, int), int>{};
  for (var p = 0; p < pages.length; p++) {
    final lines = pages[p];
    for (final pos in const [0, 1, -1, -2]) {
      final li = pos >= 0 ? pos : lines.length + pos;
      if (li < 0 || li >= lines.length) continue;
      final t = lines[li].trim();
      if (RegExp(r'^\d{1,4}$').hasMatch(t)) {
        final key = (pos, int.parse(t) - (p + 1));
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.value >= pages.length * 0.3 && best.value >= 3 ? best.key : null;
}

/// Anexa [piece] ao texto do versículo tratando hifenização no fim de linha.
void _append(StringBuffer sb, String piece) {
  if (piece == '\n') {
    if (sb.isNotEmpty) sb.write('\n');
    return;
  }
  final current = sb.toString();
  if (current.endsWith('-\n')) {
    final word = RegExp(r'^[a-zà-ÿ]+').stringMatch(piece.trimLeft()) ?? '';
    final base = current.substring(0, current.length - 2);
    sb.clear();
    if (word.isNotEmpty && !_enclitics.contains(word) && RegExp(r'[a-zà-ÿ]$').hasMatch(base)) {
      sb.write(base);
    } else {
      sb.write('$base-');
    }
    sb.write(piece.trimLeft());
    return;
  }
  if (current.endsWith('\n')) {
    sb.clear();
    sb.write(current.substring(0, current.length - 1));
    if (sb.isNotEmpty) sb.write(' ');
    sb.write(piece.trimLeft());
    return;
  }
  sb.write(piece);
}

String _clean(String s) => s
    .replaceAll('\n', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
    .trim();

/// Estrutura o texto extraído do PDF em livro/capítulo/versículo.
///
/// Usa a sequência numérica dos versículos e a quantidade conhecida de
/// capítulos de cada livro para detectar mudanças de capítulo e de livro.
/// Nada é inventado: capítulos que não puderem ser reconhecidos ficam
/// ausentes e são relatados.
BibleParseResult parseBibleText(List<List<String>> pages) {
  BibleParseResult? best;
  for (final mode in const [_Mode.smallStart, _Mode.dropSmall, _Mode.lineStart, _Mode.all]) {
    final r = _parse(pages, mode);
    if (best == null || r.parsedChapters.length > best.parsedChapters.length) best = r;
    if (r.isComplete && r.suspectChapters.isEmpty) break;
  }
  return best!;
}

BibleParseResult _parse(List<List<String>> pages, _Mode mode) {
  final toks = _tokenize(pages, mode);
  final verses = <ParsedVerse>[];
  final chapterPages = <int, int>{};
  final bookPages = <int, int>{};
  final result = BibleParseResult(verses, chapterPages, bookPages);

  var b = 0, c = 0, v = 0;
  StringBuffer? buf;
  var verseStartPage = 1;
  final pendingTitles = <String>[];

  void flush() {
    if (buf != null && v > 0) {
      final text = _clean(buf.toString());
      verses.add(ParsedVerse(b, c, v, text, verseStartPage));
      if (text.length < 2 || text.length > 1500) {
        result.suspectChapters.add(b * 1000 + c);
      }
    }
    buf = null;
  }

  List<int> peek(int from, int count) {
    final out = <int>[];
    for (var i = from + 1; i < toks.length && out.length < count; i++) {
      if (toks[i].type == _TokType.number) out.add(toks[i].n);
    }
    return out;
  }

  void startChapter(int book, int chapter, int i) {
    flush();
    pendingTitles.clear();
    if (book != b) bookPages[book] = toks[i].page;
    b = book;
    c = chapter;
    chapterPages[b * 1000 + c] = toks[i].page;
    final next = peek(i, 1);
    // Capitular sem "1" explícito: o texto que segue já é o versículo 1.
    if (next.isNotEmpty && next.first == 2) {
      v = 1;
      buf = StringBuffer();
      verseStartPage = toks[i].page;
    } else {
      v = 0;
    }
  }

  var start = 0;
  // Âncora: Gênesis 1:1 ("No princípio criou Deus...").
  for (var i = 0; i < toks.length; i++) {
    final t = toks[i];
    if (t.type == _TokType.text && normalize(t.text).contains('no principio')) {
      var j = i - 1;
      while (j >= 0 && toks[j].type != _TokType.number) {
        j--;
      }
      if (j >= 0 && (toks[j].n == 1 || toks[j].kind != _NumKind.inline)) {
        start = j;
      } else {
        start = i;
        b = 1;
        c = 1;
        v = 1;
        bookPages[1] = t.page;
        chapterPages[1001] = t.page;
        verseStartPage = t.page;
        buf = StringBuffer();
      }
      break;
    }
  }

  for (var i = start; i < toks.length; i++) {
    final t = toks[i];
    if (t.type == _TokType.title) {
      pendingTitles.add(t.text);
      continue;
    }
    if (t.type == _TokType.text) {
      if (buf != null) {
        for (final title in pendingTitles) {
          _append(buf!, ' $title ');
        }
        pendingTitles.clear();
        _append(buf!, t.text);
      }
      continue;
    }
    final n = t.n;
    final next = peek(i, 1);
    final startsChapter = next.isNotEmpty && (next.first == 1 || next.first == 2);

    if (b == 0) {
      if (n == 1 && startsChapter) startChapter(1, 1, i);
      continue;
    }
    if (b == 66 && c == 22 && v >= 21) break; // fim de Apocalipse
    final maxCh = bookById(b).chapters;
    final canNextChapter = c + 1 <= maxCh && n == c + 1;
    final canNextBook = n == 1 && c == maxCh && b < 66;

    if (t.kind == _NumKind.chapterHint) {
      // Exige que o próximo número seja 1 ou 2 (evita cabeçalhos de página).
      if (!startsChapter) continue;
      if (canNextChapter) {
        startChapter(b, c + 1, i);
      } else if (canNextBook) {
        startChapter(b + 1, 1, i);
      }
      continue;
    }
    // Layout ARC: versículo "1" seguido de "2" abre o próximo capítulo/livro,
    // mesmo quando o número do capítulo aparece fora de ordem na página.
    if (t.kind == _NumKind.verseStart && n == 1 && v >= 1 && next.isNotEmpty && next.first == 2) {
      if (c + 1 <= maxCh) {
        startChapter(b, c + 1, i);
        continue;
      }
      if (b < 66) {
        startChapter(b + 1, 1, i);
        continue;
      }
    }
    if (n == v + 1) {
      final looksLikeChapter =
          canNextChapter && startsChapter && next.first != n + 1;
      if (looksLikeChapter && t.kind == _NumKind.lone) {
        startChapter(b, c + 1, i);
      } else {
        flush();
        pendingTitles.clear();
        v = n;
        buf = StringBuffer();
        verseStartPage = t.page;
      }
      continue;
    }
    if (canNextChapter && startsChapter && v >= 1) {
      startChapter(b, c + 1, i);
      continue;
    }
    if (canNextBook && startsChapter && v >= 1) {
      startChapter(b + 1, 1, i);
      continue;
    }
    // Número não estrutural: mantém no texto se estava no meio da linha.
    if (t.kind == _NumKind.inline && buf != null) _append(buf!, '${t.text} ');
  }
  flush();

  // Último versículo: descarta material posterior a "Amém." (apêndices).
  if (verses.isNotEmpty) {
    final last = verses.last;
    if (last.book == 66 && last.chapter == 22) {
      final idx = last.text.indexOf(RegExp(r'Amém\.?'));
      if (idx >= 0) {
        final end = last.text.indexOf('.', idx);
        last.text = last.text.substring(0, end >= 0 ? end + 1 : last.text.length);
      }
    }
  }
  _validate(result);
  return result;
}

/// Marca capítulos com sinais de erro de extração.
void _validate(BibleParseResult r) {
  final perChapter = <int, int>{};
  for (final v in r.verses) {
    perChapter[v.book * 1000 + v.chapter] = v.verse;
  }
  perChapter.forEach((key, count) {
    // Nenhum capítulo do cânon tem só 1 versículo.
    if (count < 2) r.suspectChapters.add(key);
  });
}

/// Palavra posicionada na página (coordenadas em pontos PDF).
class WordBox {
  const WordBox(this.text, this.left, this.top, this.width, this.height, [this.fontSize = 0]);
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double fontSize;
  double get right => left + width;
}

/// Reconstrói as linhas de uma página em ordem de leitura, separando
/// automaticamente layouts de duas colunas (lê a coluna esquerda inteira
/// antes da direita).
/// Marca números em fonte menor que o texto (chamadas de nota/sobrescritos).
const String smallMark = '\u0001';

List<String> orderPageLines(List<WordBox> words, double pageWidth) {
  if (words.isEmpty) return const [];
  final sizes = [
    for (final w in words)
      if (w.fontSize > 0 && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(w.text)) w.fontSize,
  ]..sort();
  final small = sizes.isEmpty ? 0.0 : sizes[sizes.length ~/ 2] * 0.8;
  List<String> group(List<WordBox> ws) => _groupLines(ws, small);
  double? gutter;
  final lineCount = group(words).length;
  var best = 1 << 30;
  for (var f = 0.35; f <= 0.65; f += 0.01) {
    final x = pageWidth * f;
    final crossing = words.where((w) => w.left < x && w.right > x).length;
    if (crossing < best) {
      best = crossing;
      gutter = x;
    }
  }
  final left = words.where((w) => w.right <= gutter!).length;
  final right = words.where((w) => w.left >= gutter!).length;
  final twoColumns = best <= (lineCount * 0.05).ceil() &&
      left > words.length * 0.2 &&
      right > words.length * 0.2 &&
      group(words.where((w) => w.left >= gutter!).toList()).length >= 3 &&
      group(words.where((w) => w.right <= gutter!).toList()).length >= 3;
  if (!twoColumns) return group(words);
  final spanning = words.where((w) => w.left < gutter! && w.right > gutter).toList();
  final col1 = words.where((w) => w.right <= gutter!).toList();
  final col2 = words.where((w) => w.left >= gutter!).toList();
  // Linhas que cruzam o centro (títulos) entram na posição vertical correta
  // da primeira coluna.
  return [...group([...spanning, ...col1]), ...group(col2)];
}

List<String> _groupLines(List<WordBox> words, [double small = 0]) {
  final sorted = [...words]..sort((a, b) => a.top.compareTo(b.top));
  final lines = <List<WordBox>>[];
  for (final w in sorted) {
    if (lines.isNotEmpty) {
      final ref = lines.last.first;
      final tol = (ref.height < w.height ? ref.height : w.height) * 0.5;
      if ((w.top - ref.top).abs() <= tol) {
        lines.last.add(w);
        continue;
      }
    }
    lines.add([w]);
  }
  return [for (final l in lines) _joinLine(l..sort((a, b) => a.left.compareTo(b.left)), small)];
}

/// Junta as palavras de uma linha. Alguns PDFs entregam cada letra como uma
/// "palavra": só insere espaço quando há um vão real entre as caixas.
String _joinLine(List<WordBox> words, [double small = 0]) {
  final sb = StringBuffer();
  var inSmallNumber = false;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    var spaced = false;
    if (i > 0) {
      final prev = words[i - 1];
      final h = prev.height < w.height ? prev.height : w.height;
      final gap = w.left - prev.right;
      if (gap > h * 0.15) {
        sb.write(' ');
        spaced = true;
      }
    }
    final isSmallDigit =
        w.fontSize > 0 && w.fontSize < small && RegExp(r'^\d+$').hasMatch(w.text);
    if (isSmallDigit && (!inSmallNumber || spaced)) sb.write(smallMark);
    inSmallNumber = isSmallDigit;
    sb.write(w.text);
  }
  return sb.toString();
}
