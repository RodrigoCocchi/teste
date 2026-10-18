import 'dart:io';
import 'dart:ui';

import 'package:biblia_hinos_ccb/services/pdf_text_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Gera um PDF real em duas colunas com texto de TESTE (não bíblico) e
/// confere extração (syncfusion, em isolate) + ordenação de colunas + parser.
void main() {
  test('extrai e estrutura um PDF em duas colunas', () async {
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 0;
    final font = PdfStandardFont(PdfFontFamily.timesRoman, 10);
    final big = PdfStandardFont(PdfFontFamily.timesRoman, 16);
    // Conteúdo: Gênesis 1 (5 versículos) e 2 (4 versículos), capitular.
    final lines = <String>[
      'GÊNESIS',
      '1',
      'No princípio linha de teste um.',
      '2 Segunda linha de teste do',
      'capítulo um.',
      '3 Terceira linha de teste.',
      '4 Quarta linha de teste.',
      '5 Quinta linha de teste.',
      '2',
      'Primeira do capítulo dois.',
      '2 Segunda do capítulo dois.',
      '3 Terceira do capítulo dois.',
      '4 Quarta do capítulo dois.',
    ];
    final page = doc.pages.add();
    final width = page.getClientSize().width;
    // metade das linhas na coluna esquerda, o restante na direita
    for (var i = 0; i < lines.length; i++) {
      final left = i < 7;
      final x = left ? 40.0 : width / 2 + 20;
      final y = 60.0 + (left ? i : i - 7) * 16;
      page.graphics.drawString(lines[i], lines[i] == 'GÊNESIS' ? big : font,
          bounds: Rect.fromLTWH(x, y, width / 2 - 70, 16));
    }
    final dir = await Directory.systemTemp.createTemp('bh_pdf');
    final file = File('${dir.path}/teste.pdf');
    await file.writeAsBytes(await doc.save());
    doc.dispose();

    final progress = <int>[];
    final r = await PdfTextService.parseBible(file.path, onProgress: (p) => progress.add(p.page));
    expect(progress, isNotEmpty);
    final gn1 = r.verses.where((v) => v.book == 1 && v.chapter == 1).toList();
    final gn2 = r.verses.where((v) => v.book == 1 && v.chapter == 2).toList();
    expect(gn1.map((v) => v.verse), [1, 2, 3, 4, 5], reason: r.summary());
    expect(gn2.map((v) => v.verse), [1, 2, 3, 4], reason: r.summary());
    expect(gn1[1].text, 'Segunda linha de teste do capítulo um.');
    expect(gn2[0].text, 'Primeira do capítulo dois.');
    expect(r.chapterPages[1001], 1);
    expect(r.missingChapters.length, 1189 - 2);
  });

  test('PDF sem texto não gera versículos', () async {
    final doc = PdfDocument()..pages.add();
    final dir = await Directory.systemTemp.createTemp('bh_pdf');
    final file = File('${dir.path}/vazio.pdf');
    await file.writeAsBytes(await doc.save());
    doc.dispose();
    final r = await PdfTextService.parseBible(file.path);
    expect(r.verses, isEmpty);
  });

  test('arquivo inválido gera erro tratado', () async {
    final dir = await Directory.systemTemp.createTemp('bh_pdf');
    final file = File('${dir.path}/ruim.pdf')..writeAsStringSync('não é pdf');
    expect(PdfTextService.parseBible(file.path), throwsException);
  });
}
