/// Utilitários de texto: normalização sem acentos e tokenização.
library;

const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acentos ("Êxodo" → "exodo", "cinqüenta" → "cinquenta").
String normalize(String input) {
  final lower = input.toLowerCase();
  final sb = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(_diacritics[ch] ?? ch);
  }
  return sb.toString();
}

final RegExp _nonWord = RegExp(r'[^a-z0-9]+');

/// Palavras normalizadas (hífens e pontuação separam palavras).
List<String> tokenize(String input) =>
    normalize(input).split(_nonWord).where((w) => w.isNotEmpty).toList();

/// Texto normalizado para indexação FTS: apenas palavras separadas por espaço.
String ftsText(String input) => tokenize(input).join(' ');
