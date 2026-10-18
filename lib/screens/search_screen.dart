import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bible_ref.dart';
import '../core/text_utils.dart';
import '../data/bible_books.dart';
import '../data/bible_repository.dart';
import '../data/content.dart';
import '../data/hymn_repository.dart';
import '../services/app_services.dart';
import '../theme.dart';
import 'nav.dart';
import 'quiz_play_screen.dart';
import 'themes_screen.dart';

const _stopwords = {
  'a', 'o', 'as', 'os', 'de', 'da', 'do', 'das', 'dos', 'e', 'em', 'no', 'na', 'nos', 'nas',
  'um', 'uma', 'que', 'para', 'por', 'com', 'se', 'ao', 'aos', 'foi', 'era', 'qual', 'quem',
  'quantos', 'quantas', 'onde', 'como', 'quando', 'seu', 'sua',
};

/// Pesquisa universal: referências, palavras/expressões, temas, hinos e perguntas.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial = ''});
  final String initial;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  Timer? _debounce;
  bool _exact = false;
  String _query = '';
  BibleRef? _ref;
  BibleBook? _book;
  SearchHits _verses = const SearchHits([], 0);
  List<Hymn> _hymns = [];
  List<BibleThemeData> _themes = [];
  List<QuizQuestion> _questions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) _run(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(v));
  }

  Future<void> _run(String raw) async {
    final q = raw.trim();
    final exact = _exact || (q.startsWith('"') && q.endsWith('"') && q.length > 2);
    final text = q.replaceAll('"', '');
    if (text.isEmpty) {
      setState(() {
        _query = '';
        _ref = null;
        _book = null;
        _verses = const SearchHits([], 0);
        _hymns = [];
        _themes = [];
        _questions = [];
      });
      return;
    }
    setState(() => _loading = true);
    final app = App.I;
    final ref = RegExp(r'\d').hasMatch(text) ? BibleRef.tryParse(text) : null;
    final book = ref == null ? findBook(text) : null;
    final hymnQuery = RegExp(r'^\s*(hino|coro)\b', caseSensitive: false).hasMatch(text) ||
        RegExp(r'^\s*\d{1,3}\s*$').hasMatch(text);
    final hymns = await app.hymns.search(text);
    final verses = app.hasBibleText && !hymnQuery && ref == null
        ? await app.bible.search(text, exact: exact)
        : const SearchHits([], 0);
    final words = tokenize(text).where((w) => !_stopwords.contains(w)).toList();
    final themes = app.themes
        .where((t) => words.isNotEmpty && words.every((w) => tokenize(t.name).any((x) => x.startsWith(w))))
        .toList();
    final questions = <(double, QuizQuestion)>[];
    if (words.isNotEmpty) {
      for (final qq in app.questions) {
        final qt = tokenize('${qq.question} ${qq.category}').toSet();
        final hit = words.where((w) => qt.any((x) => x.startsWith(w))).length;
        final score = hit / words.length;
        if (score >= 0.6) questions.add((score, qq));
      }
      questions.sort((a, b) => b.$1.compareTo(a.$1));
    }
    if (!mounted || _controller.text.trim() != q) return;
    setState(() {
      _loading = false;
      _query = text;
      _ref = ref;
      _book = book;
      _verses = verses;
      _hymns = hymnQuery || hymns.length < Hymns.total ? hymns : [];
      _themes = themes;
      _questions = questions.map((e) => e.$2).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bibleCount = (_ref != null ? 1 : 0) + (_book != null ? 1 : 0) + _themes.length + _verses.total;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: widget.initial.isEmpty,
            onChanged: _changed,
            onSubmitted: _run,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            cursorColor: AppColors.gold,
            decoration: const InputDecoration(
              hintText: 'Pesquisar…',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Expressão exata',
              isSelected: _exact,
              icon: const Icon(Icons.format_quote_outlined),
              selectedIcon: const Icon(Icons.format_quote, color: AppColors.gold),
              onPressed: () {
                setState(() => _exact = !_exact);
                _run(_controller.text);
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.gold,
            tabs: [
              Tab(text: 'Bíblia${_query.isEmpty ? '' : ' ($bibleCount)'}'),
              Tab(text: 'Hinos${_query.isEmpty ? '' : ' (${_hymns.length})'}'),
              Tab(text: 'Perguntas${_query.isEmpty ? '' : ' (${_questions.length})'}'),
            ],
          ),
        ),
        body: Column(children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(children: [_bibleTab(), _hymnTab(), _questionTab()]),
          ),
        ]),
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      );

  Widget _bibleTab() {
    final app = App.I;
    if (_query.isEmpty) {
      return _hint('Exemplos: João 3:16 · Salmos 23 · Jesus chorou · perdão.\n'
          'Use aspas ou o botão de citação para a expressão exata.');
    }
    final children = <Widget>[
      if (_ref != null)
        Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            leading: const Icon(Icons.menu_book, color: AppColors.gold),
            title: Text('Abrir ${_ref!.label}'),
            subtitle: Text(app.hasBibleText ? 'Texto indexado' : 'Abrir no PDF'),
            onTap: () => openRef(context, _ref!),
          ),
        ),
      if (_book != null)
        ListTile(
          leading: const Icon(Icons.book_outlined),
          title: Text(_book!.name),
          subtitle: Text('${_book!.chapters} capítulos'),
          onTap: () => openRef(context, BibleRef(_book!.id, 1)),
        ),
      for (final t in _themes)
        ListTile(
          leading: const Icon(Icons.local_offer_outlined),
          title: Text('Tema: ${t.name}'),
          subtitle: Text(t.description),
          onTap: () => push(context, ThemeDetailScreen(theme: t)),
        ),
      if (!app.hasBibleText && _ref == null)
        _hint('A busca por palavras só funciona depois que o texto da Bíblia for importado e '
            'indexado (Configurações › Documentos). O PDF sem indexação não é pesquisável.'),
      if (_verses.total > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
              '${_verses.total} versículo(s)${_verses.total > _verses.verses.length ? ' — mostrando ${_verses.verses.length}' : ''}',
              style: Theme.of(context).textTheme.labelMedium),
        ),
      for (final v in _verses.verses)
        ListTile(
          title: Text(v.ref.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: _Highlighted(text: v.text, words: tokenize(_query)),
          onTap: () => openChapter(context, v.bookId, v.chapter, verse: v.verse),
        ),
    ];
    if (children.isEmpty) return _hint('Nada encontrado na Bíblia.');
    return ListView(children: children);
  }

  Widget _hymnTab() {
    if (_query.isEmpty) return _hint('Digite o número (ex.: 120, hino 120, coro 3) ou o título.');
    if (_hymns.isEmpty) {
      return _hint('Nenhum hino encontrado. Títulos só aparecem quando cadastrados no hinário.');
    }
    return ListView(children: [
      for (final h in _hymns.take(100))
        ListTile(
          leading: const Icon(Icons.music_note, color: AppColors.gold),
          title: Text(h.display),
          onTap: () => openHymn(context, h.number),
        ),
    ]);
  }

  Widget _questionTab() {
    if (_query.isEmpty) return _hint('Ex.: Quem construiu a arca?');
    if (_questions.isEmpty) return _hint('Nenhuma pergunta do quiz corresponde à pesquisa.');
    return ListView(children: [
      for (final q in _questions.take(50))
        ListTile(
          leading: const Icon(Icons.help_outline, color: AppColors.gold),
          title: Text(q.question),
          subtitle: Text('${QuizQuestion.difficultyLabel(q.difficulty)} · ${q.refLabel}'),
          onTap: () => push(context, QuizPlayScreen(questions: [q], difficulty: q.difficulty)),
        ),
    ]);
  }
}

class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.words});
  final String text;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'[\wÀ-ÿ]+|[^\wÀ-ÿ]+');
    for (final m in re.allMatches(text)) {
      final piece = m[0]!;
      final n = normalize(piece);
      final hit = words.any((w) => n.startsWith(w) && w.length >= 2);
      spans.add(TextSpan(
          text: piece,
          style: hit
              ? TextStyle(
                  fontWeight: FontWeight.bold,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.25))
              : null));
    }
    return Text.rich(TextSpan(children: spans), maxLines: 4, overflow: TextOverflow.ellipsis);
  }
}
