import 'bible_books.dart';

/// Capítulo do plano de leitura.
class PlanChapter {
  const PlanChapter(this.bookId, this.chapter);
  final int bookId;
  final int chapter;

  String get label => '${bookById(bookId).name} $chapter';

  @override
  bool operator ==(Object other) =>
      other is PlanChapter && other.bookId == bookId && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(bookId, chapter);
}

/// Gera o plano anual: os 1189 capítulos em ordem canônica, distribuídos de
/// forma uniforme em [days] dias (3 ou 4 capítulos por dia), sem omissões
/// nem repetições.
List<List<PlanChapter>> buildReadingPlan({int days = 365}) {
  final all = <PlanChapter>[
    for (final b in bibleBooks)
      for (var c = 1; c <= b.chapters; c++) PlanChapter(b.id, c),
  ];
  return [
    for (var d = 0; d < days; d++)
      all.sublist(all.length * d ~/ days, all.length * (d + 1) ~/ days),
  ];
}
