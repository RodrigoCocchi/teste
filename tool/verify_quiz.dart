// Confere as perguntas do quiz.
//
//   dart run tool/verify_quiz.dart                          # estrutura
//   dart run tool/verify_quiz.dart biblia_estruturada.json  # + texto bíblico
//
// O JSON da Bíblia é o exportado pelo app (Documentos › Exportar JSON) ou
// gerado por tool/extract_bible.dart. Uma pergunta só é "conferida" quando
// todas as palavras-chave aparecem no texto das referências citadas.
import 'dart:convert';
import 'dart:io';

import 'package:biblia_hinos_ccb/core/text_utils.dart';
import 'package:biblia_hinos_ccb/data/content.dart';

void main(List<String> args) {
  final questions = QuizQuestion.listFromJson(File('assets/data/quiz.json').readAsStringSync());
  final problems = <String>[];
  final ids = <String>{};
  final counts = <String, int>{};
  for (final q in questions) {
    if (!ids.add(q.id)) problems.add('${q.id}: ID repetido');
    counts[q.difficulty] = (counts[q.difficulty] ?? 0) + 1;
    if (q.options.length != 4) problems.add('${q.id}: precisa de 4 alternativas');
    if (q.options.map(normalize).toSet().length != q.options.length) {
      problems.add('${q.id}: alternativas repetidas');
    }
    if (q.answer < 0 || q.answer > 3) problems.add('${q.id}: resposta fora do intervalo');
    for (final r in q.refs) {
      if (!r.isValidChapter) problems.add('${q.id}: capítulo inexistente em ${r.label}');
    }
    if (q.keywords.isEmpty) problems.add('${q.id}: sem palavras-chave');
  }
  stdout.writeln('Perguntas: ${questions.length} $counts');

  if (args.isNotEmpty) {
    final data = jsonDecode(File(args.first).readAsStringSync()) as Map<String, dynamic>;
    final text = <int, String>{};
    for (final v in data['verses'] as List) {
      text[(v['b'] as int) * 1000000 + (v['c'] as int) * 1000 + (v['v'] as int)] = v['t'] as String;
    }
    var ok = 0, missing = 0;
    for (final q in questions) {
      final words = <String>{};
      var hasText = true;
      for (final r in q.refs) {
        final start = r.verseStart ?? 1, end = r.verseEnd ?? r.verseStart ?? 999;
        var found = false;
        for (var v = start; v <= end; v++) {
          final t = text[r.bookId * 1000000 + r.chapter * 1000 + v];
          if (t != null) {
            found = true;
            words.addAll(tokenize(t));
          }
        }
        if (!found) hasText = false;
      }
      final absent = q.keywords.expand(tokenize).where((k) => !words.contains(k)).toList();
      if (!hasText) {
        missing++;
        problems.add('${q.id}: referência sem texto (${q.refLabel})');
      } else if (absent.isNotEmpty) {
        problems.add('${q.id}: palavras não encontradas em ${q.refLabel}: ${absent.join(', ')}');
      } else {
        ok++;
      }
    }
    stdout.writeln('Conferidas com o texto: $ok · sem texto: $missing · '
        'divergentes: ${questions.length - ok - missing}');
  } else {
    stdout.writeln('Texto bíblico não informado: respostas NÃO conferidas com a Bíblia.');
  }
  for (final p in problems) {
    stdout.writeln('  - $p');
  }
  exitCode = problems.isEmpty ? 0 : 1;
}
