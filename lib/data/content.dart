import 'dart:convert';

import '../core/bible_ref.dart';

/// Pergunta do quiz (arquivo assets/data/quiz.json).
class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.difficulty,
    required this.category,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.refs,
    required this.keywords,
  });

  final String id;
  final String difficulty; // facil | medio | dificil
  final String category;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final List<BibleRef> refs;

  /// Palavras que precisam constar no texto das referências para a resposta
  /// ser considerada conferida com o texto bíblico importado.
  final List<String> keywords;

  /// Resultado da conferência com o texto: 'conferida', 'divergente' ou 'pendente'.
  String verifyStatus = 'pendente';

  String get correctOption => options[answer];
  String get refLabel => refs.map((r) => r.label).join('; ');

  static const difficulties = ['facil', 'medio', 'dificil'];
  static String difficultyLabel(String d) =>
      const {'facil': 'Fácil', 'medio': 'Média', 'dificil': 'Difícil', 'todas': 'Todas'}[d] ?? d;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        difficulty: j['difficulty'] as String,
        category: j['category'] as String,
        question: j['question'] as String,
        options: (j['options'] as List).cast<String>(),
        answer: j['answer'] as int,
        explanation: j['explanation'] as String,
        refs: (j['refs'] as List).cast<String>().map(BibleRef.parseStrict).toList(),
        keywords: (j['keywords'] as List).cast<String>(),
      );

  static List<QuizQuestion> listFromJson(String source) =>
      (jsonDecode(source)['questions'] as List)
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
}

/// Tema do índice temático (assets/data/themes.json).
class BibleThemeData {
  BibleThemeData(this.id, this.name, this.description, this.refs);
  final int id;
  final String name;
  final String description;
  final List<BibleRef> refs;

  static List<BibleThemeData> listFromJson(String source) {
    final list = jsonDecode(source)['themes'] as List;
    return [
      for (var i = 0; i < list.length; i++)
        BibleThemeData(
          i + 1,
          list[i]['name'] as String,
          list[i]['description'] as String,
          (list[i]['refs'] as List).cast<String>().map(BibleRef.parseStrict).toList(),
        ),
    ];
  }
}

/// Estudo do Dia (assets/data/studies.json). O texto bíblico NÃO fica no
/// JSON: é lido do banco a partir das referências; o JSON contém apenas as
/// explicações autorais.
class DailyStudyData {
  DailyStudyData({
    required this.id,
    required this.title,
    required this.theme,
    required this.refs,
    required this.context,
    required this.reflection,
    required this.questions,
  });

  final int id;
  final String title;
  final String theme;
  final List<BibleRef> refs;
  final String context;
  final String reflection;
  final List<String> questions;

  String get refLabel => refs.map((r) => r.label).join('; ');

  factory DailyStudyData.fromJson(Map<String, dynamic> j) => DailyStudyData(
        id: j['id'] as int,
        title: j['title'] as String,
        theme: j['theme'] as String,
        refs: (j['refs'] as List).cast<String>().map(BibleRef.parseStrict).toList(),
        context: j['context'] as String,
        reflection: j['reflection'] as String,
        questions: (j['questions'] as List).cast<String>(),
      );

  static List<DailyStudyData> listFromJson(String source) =>
      (jsonDecode(source)['studies'] as List)
          .map((e) => DailyStudyData.fromJson(e as Map<String, dynamic>))
          .toList();
}
