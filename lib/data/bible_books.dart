import '../core/text_utils.dart';

/// Livro bíblico (cânon protestante de 66 livros, ordem tradicional).
class BibleBook {
  const BibleBook(this.id, this.name, this.abbrev, this.chapters,
      [this.aliases = const []]);

  final int id;
  final String name;
  final String abbrev;
  final int chapters;
  final List<String> aliases;

  bool get isOldTestament => id <= 39;
}

const List<BibleBook> bibleBooks = [
  BibleBook(1, 'Gênesis', 'Gn', 50, ['genesis', 'gen']),
  BibleBook(2, 'Êxodo', 'Êx', 40, ['exodo', 'ex']),
  BibleBook(3, 'Levítico', 'Lv', 27, ['levitico', 'lev']),
  BibleBook(4, 'Números', 'Nm', 36, ['numeros', 'num']),
  BibleBook(5, 'Deuteronômio', 'Dt', 34, ['deuteronomio', 'deut']),
  BibleBook(6, 'Josué', 'Js', 24, ['josue']),
  BibleBook(7, 'Juízes', 'Jz', 21, ['juizes']),
  BibleBook(8, 'Rute', 'Rt', 4),
  BibleBook(9, '1 Samuel', '1Sm', 31, ['1sam']),
  BibleBook(10, '2 Samuel', '2Sm', 24, ['2sam']),
  BibleBook(11, '1 Reis', '1Rs', 22),
  BibleBook(12, '2 Reis', '2Rs', 25),
  BibleBook(13, '1 Crônicas', '1Cr', 29, ['1cronicas']),
  BibleBook(14, '2 Crônicas', '2Cr', 36, ['2cronicas']),
  BibleBook(15, 'Esdras', 'Ed', 10),
  BibleBook(16, 'Neemias', 'Ne', 13),
  BibleBook(17, 'Ester', 'Et', 10),
  BibleBook(18, 'Jó', 'Jó', 42),
  BibleBook(19, 'Salmos', 'Sl', 150, ['salmo', 'sal']),
  BibleBook(20, 'Provérbios', 'Pv', 31, ['proverbios', 'prov']),
  BibleBook(21, 'Eclesiastes', 'Ec', 12, ['ecl']),
  BibleBook(22, 'Cantares', 'Ct', 8,
      ['canticos', 'canticodoscanticos', 'cantaresdesalomao', 'cantico']),
  BibleBook(23, 'Isaías', 'Is', 66, ['isaias']),
  BibleBook(24, 'Jeremias', 'Jr', 52, ['jer']),
  BibleBook(25, 'Lamentações', 'Lm', 5,
      ['lamentacoes', 'lamentacoesdejeremias', 'lam']),
  BibleBook(26, 'Ezequiel', 'Ez', 48, ['ezeq']),
  BibleBook(27, 'Daniel', 'Dn', 12, ['dan']),
  BibleBook(28, 'Oséias', 'Os', 14, ['oseias']),
  BibleBook(29, 'Joel', 'Jl', 3),
  BibleBook(30, 'Amós', 'Am', 9, ['amos']),
  BibleBook(31, 'Obadias', 'Ob', 1),
  BibleBook(32, 'Jonas', 'Jn', 4),
  BibleBook(33, 'Miquéias', 'Mq', 7, ['miqueias']),
  BibleBook(34, 'Naum', 'Na', 3),
  BibleBook(35, 'Habacuque', 'Hc', 3),
  BibleBook(36, 'Sofonias', 'Sf', 3),
  BibleBook(37, 'Ageu', 'Ag', 2),
  BibleBook(38, 'Zacarias', 'Zc', 14),
  BibleBook(39, 'Malaquias', 'Ml', 4),
  BibleBook(40, 'Mateus', 'Mt', 28),
  BibleBook(41, 'Marcos', 'Mc', 16),
  BibleBook(42, 'Lucas', 'Lc', 24),
  BibleBook(43, 'João', 'Jo', 21, ['joao']),
  BibleBook(44, 'Atos', 'At', 28, ['atosdosapostolos']),
  BibleBook(45, 'Romanos', 'Rm', 16, ['rom']),
  BibleBook(46, '1 Coríntios', '1Co', 16, ['1corintios', '1cor']),
  BibleBook(47, '2 Coríntios', '2Co', 13, ['2corintios', '2cor']),
  BibleBook(48, 'Gálatas', 'Gl', 6, ['galatas', 'gal']),
  BibleBook(49, 'Efésios', 'Ef', 6, ['efesios']),
  BibleBook(50, 'Filipenses', 'Fp', 4, ['fil']),
  BibleBook(51, 'Colossenses', 'Cl', 4, ['col']),
  BibleBook(52, '1 Tessalonicenses', '1Ts', 5),
  BibleBook(53, '2 Tessalonicenses', '2Ts', 3),
  BibleBook(54, '1 Timóteo', '1Tm', 6, ['1timoteo']),
  BibleBook(55, '2 Timóteo', '2Tm', 4, ['2timoteo']),
  BibleBook(56, 'Tito', 'Tt', 3),
  BibleBook(57, 'Filemom', 'Fm', 1, ['filemon']),
  BibleBook(58, 'Hebreus', 'Hb', 13, ['heb']),
  BibleBook(59, 'Tiago', 'Tg', 5),
  BibleBook(60, '1 Pedro', '1Pe', 5),
  BibleBook(61, '2 Pedro', '2Pe', 3),
  BibleBook(62, '1 João', '1Jo', 5, ['1joao']),
  BibleBook(63, '2 João', '2Jo', 1, ['2joao']),
  BibleBook(64, '3 João', '3Jo', 1, ['3joao']),
  BibleBook(65, 'Judas', 'Jd', 1),
  BibleBook(66, 'Apocalipse', 'Ap', 22, ['apoc']),
];

/// Total de capítulos do cânon (1189).
final int totalBibleChapters =
    bibleBooks.fold(0, (sum, b) => sum + b.chapters);

BibleBook bookById(int id) => bibleBooks[id - 1];

String _key(String s) => normalize(s).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Chaves exatas (sem acento) → livro. "jo" é João; "Jó" é tratado à parte.
final Map<String, BibleBook> _exactKeys = () {
  final map = <String, BibleBook>{};
  for (final b in bibleBooks.reversed) {
    map[_key(b.name)] = b;
    map[_key(b.abbrev)] = b;
    for (final a in b.aliases) {
      map[_key(a)] = b;
    }
  }
  map['jo'] = bookById(43);
  map['job'] = bookById(18);
  return map;
}();

/// Localiza um livro por nome, abreviação ou prefixo, sem diferenciar
/// maiúsculas/acentos. Aceita "1 Co", "I Coríntios", "1ª Coríntios".
BibleBook? findBook(String query) {
  var q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  if (q == 'jó' || q == 'jó.') return bookById(18);
  q = q.replaceFirstMapped(
      RegExp(r'^(iii|ii|i|1|2|3)\s*(ª|º|a|o)?\.?\s+(?=[a-zà-ÿ])'),
      (m) => '${_roman(m[1]!)} ');
  q = q.replaceFirstMapped(
      RegExp(r'^(primeira|primeiro|segunda|segundo|terceira|terceiro)\s+'),
      (m) => '${m[1]!.startsWith('prim') ? 1 : m[1]!.startsWith('seg') ? 2 : 3} ');
  final k = _key(q);
  if (k.isEmpty) return null;
  final exact = _exactKeys[k];
  if (exact != null) return exact;
  if (k.length < 2) return null;
  for (final b in bibleBooks) {
    if (_key(b.name).startsWith(k)) return b;
  }
  for (final b in bibleBooks) {
    if (b.aliases.any((a) => _key(a).startsWith(k))) return b;
  }
  return null;
}

String _roman(String s) => switch (s) {
      'i' => '1',
      'ii' => '2',
      'iii' => '3',
      _ => s,
    };
