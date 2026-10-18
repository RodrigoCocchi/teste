import 'package:flutter/material.dart';

import '../core/bible_ref.dart';
import 'bible_pdf_screen.dart';
import 'hymn_viewer_screen.dart';
import 'reader_screen.dart';
import '../services/app_services.dart';

Future<void> openChapter(BuildContext context, int book, int chapter, {int? verse, int? verseEnd}) {
  return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(book: book, chapter: chapter, highlight: verse, highlightEnd: verseEnd)));
}

/// Abre uma referência: no texto estruturado, se houver; senão, no PDF.
Future<void> openRef(BuildContext context, BibleRef ref) async {
  if (App.I.hasBibleText) {
    return openChapter(context, ref.bookId, ref.chapter, verse: ref.verseStart, verseEnd: ref.verseEnd);
  }
  return openBiblePdf(context, book: ref.bookId, chapter: ref.chapter);
}

Future<void> openBiblePdf(BuildContext context, {int? book, int? chapter, int? page}) {
  return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BiblePdfScreen(book: book, chapter: chapter, page: page)));
}

Future<void> openHymn(BuildContext context, int number) {
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => HymnViewerScreen(number: number)));
}

Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));
