import 'dart:io';

import 'package:biblia_hinos_ccb/core/bible_ref.dart';
import 'package:biblia_hinos_ccb/core/text_utils.dart';
import 'package:biblia_hinos_ccb/data/bible_books.dart';
import 'package:biblia_hinos_ccb/data/content.dart';
import 'package:biblia_hinos_ccb/data/reading_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Livros', () {
    test('66 livros, 39 AT + 27 NT, 1189 capítulos', () {
      expect(bibleBooks.length, 66);
      expect(bibleBooks.where((b) => b.isOldTestament).length, 39);
      expect(bibleBooks.where((b) => !b.isOldTestament).length, 27);
      expect(totalBibleChapters, 1189);
      for (var i = 0; i < 66; i++) {
        expect(bibleBooks[i].id, i + 1);
      }
    });

    test('localiza por nome e abreviação', () {
      expect(findBook('João')?.id, 43);
      expect(findBook('jo')?.id, 43);
      expect(findBook('Jó')?.id, 18);
      expect(findBook('salmo')?.id, 19);
      expect(findBook('1 Co')?.id, 46);
      expect(findBook('I Coríntios')?.id, 46);
      expect(findBook('2ª Timóteo')?.id, 55);
      expect(findBook('Ex')?.id, 2);
      expect(findBook('apocalipse')?.id, 66);
      expect(findBook('perdão'), isNull);
      for (final b in bibleBooks) {
        expect(findBook(b.name)?.id, b.id, reason: b.name);
        expect(findBook(b.abbrev)?.id, b.id, reason: b.abbrev);
      }
    });
  });

  group('Referências', () {
    test('formatos aceitos', () {
      expect(BibleRef.tryParse('João 3:16'), const BibleRef(43, 3, 16));
      expect(BibleRef.tryParse('Jo 3.16-18'), const BibleRef(43, 3, 16, 18));
      expect(BibleRef.tryParse('Salmos 23'), const BibleRef(19, 23));
      expect(BibleRef.tryParse('1 Co 13'), const BibleRef(46, 13));
      expect(BibleRef.tryParse('1Coríntios 13:4-7'), const BibleRef(46, 13, 4, 7));
      expect(BibleRef.tryParse('Gênesis'), const BibleRef(1, 1));
      expect(BibleRef.tryParse('Jó 1:1'), const BibleRef(18, 1, 1));
    });
    test('rejeita inválidas', () {
      expect(BibleRef.tryParse('Jesus chorou'), isNull);
      expect(BibleRef.tryParse('Hino 120'), isNull);
      expect(BibleRef.tryParse('Gênesis 51'), isNull);
      expect(BibleRef.tryParse('Jo 3:5-2'), isNull);
    });
  });

  test('normalização sem acentos', () {
    expect(normalize('Êxodo CINQÜENTA'), 'exodo cinquenta');
    expect(tokenize('Disse-lhe: Perdão!'), ['disse', 'lhe', 'perdao']);
  });

  group('Quiz (assets/data/quiz.json)', () {
    final questions = QuizQuestion.listFromJson(File('assets/data/quiz.json').readAsStringSync());

    test('120 perguntas: 40 fáceis, 40 médias, 40 difíceis', () {
      expect(questions.length, 120);
      for (final d in QuizQuestion.difficulties) {
        expect(questions.where((q) => q.difficulty == d).length, greaterThanOrEqualTo(40), reason: d);
      }
    });

    test('IDs únicos e enunciados únicos', () {
      expect(questions.map((q) => q.id).toSet().length, questions.length);
      expect(questions.map((q) => normalize(q.question)).toSet().length, questions.length);
    });

    test('estrutura completa e consistente', () {
      for (final q in questions) {
        expect(QuizQuestion.difficulties, contains(q.difficulty), reason: q.id);
        expect(q.options.length, 4, reason: q.id);
        expect(q.options.map(normalize).toSet().length, 4, reason: '${q.id}: alternativas repetidas');
        expect(q.options.every((o) => o.trim().isNotEmpty), isTrue, reason: q.id);
        expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
        expect(q.explanation.trim(), isNotEmpty, reason: q.id);
        expect(q.category.trim(), isNotEmpty, reason: q.id);
        expect(q.question.trim().endsWith('?'), isTrue, reason: q.id);
        expect(q.refs, isNotEmpty, reason: q.id);
        expect(q.keywords, isNotEmpty, reason: q.id);
        for (final r in q.refs) {
          expect(r.isValidChapter, isTrue, reason: '${q.id} ${r.label}');
          expect(r.verseStart, isNotNull, reason: '${q.id}: referência sem versículo');
          expect(r.verseStart, greaterThan(0));
          expect(r.lastVerse, lessThan(200), reason: '${q.id} ${r.label}');
        }
        expect(q.verifyStatus, 'pendente', reason: 'JSON não pode se declarar conferido');
      }
    });

    test('palavras-chave relacionadas à resposta correta', () {
      // A resposta certa deve compartilhar ao menos uma palavra-chave com a
      // explicação, garantindo coerência entre resposta, explicação e conferência.
      for (final q in questions) {
        final expl = tokenize(q.explanation).toSet();
        final kws = q.keywords.expand(tokenize).toList();
        expect(kws.any(expl.contains), isTrue, reason: q.id);
      }
    });
  });

  test('temas: 21 categorias com referências válidas', () {
    final themes = BibleThemeData.listFromJson(File('assets/data/themes.json').readAsStringSync());
    expect(themes.map((t) => t.name), containsAll(['Amor', 'Fé', 'Esperança', 'Salvação', 'Perdão',
      'Oração', 'Família', 'Casamento', 'Filhos', 'Sabedoria', 'Obediência', 'Humildade',
      'Arrependimento', 'Batismo', 'Espírito Santo', 'Ressurreição', 'Vida Eterna', 'Consolação',
      'Gratidão', 'Paz', 'Santificação']));
    for (final t in themes) {
      expect(t.refs.length, greaterThanOrEqualTo(3), reason: t.name);
      for (final r in t.refs) {
        expect(r.isValidChapter && r.verseStart != null, isTrue, reason: '${t.name} ${r.label}');
      }
    }
  });

  test('estudos: estrutura e sem duplicação', () {
    final studies = DailyStudyData.listFromJson(File('assets/data/studies.json').readAsStringSync());
    expect(studies.length, greaterThanOrEqualTo(30));
    expect(studies.map((s) => s.id).toSet().length, studies.length);
    expect(studies.map((s) => s.title).toSet().length, studies.length);
    expect(studies.map((s) => s.reflection).toSet().length, studies.length);
    for (final s in studies) {
      expect(s.questions.length, 3, reason: s.title);
      expect(s.refs, isNotEmpty);
      for (final r in s.refs) {
        expect(r.isValidChapter, isTrue, reason: '${s.title} ${r.label}');
      }
    }
  });

  test('plano anual cobre os 1189 capítulos sem repetição', () {
    final plan = buildReadingPlan();
    expect(plan.length, 365);
    final all = plan.expand((d) => d).toList();
    expect(all.length, 1189);
    expect(all.toSet().length, 1189);
    for (final b in bibleBooks) {
      for (var c = 1; c <= b.chapters; c++) {
        expect(all.contains(PlanChapter(b.id, c)), isTrue);
      }
    }
    expect(plan.every((d) => d.length >= 3 && d.length <= 4), isTrue);
  });
}
