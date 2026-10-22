import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_books.dart';
import '../data/bible_repository.dart';
import '../data/user_repository.dart';
import '../services/app_services.dart';
import '../services/bible_audio.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'verse_image_screen.dart';

/// Leitor de capítulo com numeração, seleção de versículos, cópia,
/// compartilhamento, favoritos, marcações, notas e modo leitura.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.chapter, this.highlight, this.highlightEnd});
  final int book;
  final int chapter;
  final int? highlight;
  final int? highlightEnd;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _book = widget.book;
  late int _chapter = widget.chapter;
  int? _highlight;
  int? _highlightEnd;
  List<Verse> _verses = [];
  ChapterInfo? _info;
  Map<int, Bookmark> _marks = {};
  Set<String> _favs = {};
  final Set<int> _selected = {};
  bool _loading = true;
  bool _readingMode = false;
  final _keys = <int, GlobalKey>{};
  final _scroll = ScrollController();
  final _audio = ChapterAudio(DeviceSpeech());
  bool _autoNext = true;

  @override
  void initState() {
    super.initState();
    _highlight = widget.highlight;
    _highlightEnd = widget.highlightEnd;
    _audio
      ..addListener(_onAudio)
      ..onChapterEnd = _onChapterEnd;
    SharedPreferences.getInstance().then((p) {
      final sp = p.getString('audioSpeed');
      if (sp != null && audioSpeeds.containsKey(sp)) _audio.speed = sp;
      _autoNext = p.getBool('audioAutoNext') ?? true;
    });
    _load();
  }

  // ---------------------------------------------------------------- áudio

  void _onAudio() {
    if (!mounted) return;
    setState(() {});
    final n = _audio.current;
    if (_audio.state == AudioState.playing && n != null) {
      final ctx = _keys[n]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 400));
      }
    }
  }

  Future<void> _listen({int? from}) async {
    setState(_selected.clear);
    if (_verses.isEmpty) return;
    final f = _audio.play('${_b.name}, capítulo $_chapter', [for (final v in _verses) (v.verse, v.text)], from: from);
    // Aguarda só o início para avisar se o aparelho não tem voz em português.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted && _audio.voiceAvailable == false) {
      showSnack(context,
          'Sem voz em português no celular. Instale em Configurações > Gerenciamento geral > Conversão de texto em voz.');
    }
    await f;
  }

  Future<void> _onChapterEnd() async {
    if (!mounted || !_autoNext || (_book == 66 && _chapter == 22)) return;
    await _go(1);
    if (mounted) _listen();
  }

  Future<void> _setSpeed(String s) async {
    (await SharedPreferences.getInstance()).setString('audioSpeed', s);
    await _audio.setSpeed(s);
  }

  @override
  void dispose() {
    if (_readingMode) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scroll.dispose();
    _audio.dispose();
    super.dispose();
  }

  BibleBook get _b => bookById(_book);

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = App.I;
    final verses = await app.bible.chapter(_book, _chapter);
    final info = await app.bible.chapterInfo(_book, _chapter);
    final marks = await app.user.bookmarksInChapter(_book, _chapter);
    final favs = await app.user.favoriteKeys('verse');
    if (!mounted) return;
    setState(() {
      _verses = verses;
      _info = info;
      _marks = marks;
      _favs = favs;
      _selected.clear();
      _loading = false;
      _keys
        ..clear()
        ..addAll({for (final v in verses) v.verse: GlobalKey()});
    });
    if (verses.isNotEmpty) {
      app.settings.setLastChapter(_book, _chapter);
      app.user.addHistory('chapter', '$_book:$_chapter', '${_b.name} $_chapter');
    }
    final target = _highlight;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[target]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 300));
        }
      });
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _go(int delta) {
    var b = _book, c = _chapter + delta;
    if (c < 1) {
      if (b == 1) return Future.value();
      b--;
      c = bookById(b).chapters;
    } else if (c > bookById(b).chapters) {
      if (b == 66) return Future.value();
      b++;
      c = 1;
    }
    setState(() {
      _book = b;
      _chapter = c;
      _highlight = null;
      _highlightEnd = null;
    });
    return _load();
  }

  List<Verse> get _selectedVerses =>
      _verses.where((v) => _selected.contains(v.verse)).toList();

  String _selectionText() {
    final vs = _selectedVerses;
    if (vs.isEmpty) return '';
    final nums = vs.map((v) => v.verse).toList();
    final contiguous = nums.last - nums.first == nums.length - 1;
    final label = nums.length == 1
        ? '${_b.name} $_chapter:${nums.first}'
        : contiguous
            ? '${_b.name} $_chapter:${nums.first}-${nums.last}'
            : '${_b.name} $_chapter:${nums.join(',')}';
    final body = vs.map((v) => vs.length == 1 ? v.text : '${v.verse} ${v.text}').join(' ');
    return '"$body"\n— $label (ARC)';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _selectionText()));
    if (mounted) showSnack(context, 'Versículo(s) copiado(s)');
    setState(_selected.clear);
  }

  void _shareImage() {
    final vs = _selectedVerses;
    if (vs.isEmpty) return;
    final text = _selectionText();
    final cut = text.lastIndexOf('\n— ');
    final body = vs.map((v) => vs.length == 1 ? v.text : '${v.verse} ${v.text}').join(' ');
    final ref = cut < 0 ? '' : text.substring(cut + 3);
    setState(_selected.clear);
    push(context, VerseImageScreen(text: body, reference: ref));
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: _selectionText()));
    setState(_selected.clear);
  }

  Future<void> _toggleFavorite() async {
    final user = App.I.user;
    for (final v in _selectedVerses) {
      await user.toggleFavorite('verse', '${v.id}', v.ref.label);
    }
    _favs = await user.favoriteKeys('verse');
    setState(_selected.clear);
  }

  Future<void> _mark(int? color) async {
    for (final v in _selectedVerses) {
      await App.I.user.setBookmark(v.id, color: color, note: _marks[v.id]?.note);
    }
    _marks = await App.I.user.bookmarksInChapter(_book, _chapter);
    setState(_selected.clear);
  }

  Future<void> _note() async {
    final vs = _selectedVerses;
    if (vs.isEmpty) return;
    final first = vs.first;
    final ctrl = TextEditingController(text: _marks[first.id]?.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anotação · ${first.ref.label}'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Sua anotação pessoal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Apagar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (result == null) return;
    for (final v in vs) {
      await App.I.user.setBookmark(v.id, color: _marks[v.id]?.color, note: result);
    }
    _marks = await App.I.user.bookmarksInChapter(_book, _chapter);
    setState(_selected.clear);
  }

  void _toggleReadingMode() {
    setState(() => _readingMode = !_readingMode);
    SystemChrome.setEnabledSystemUIMode(
        _readingMode ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  Future<void> _fontDialog() async {
    final s = App.I.settings;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Tamanho da fonte: ${s.fontSize.round()}'),
            Slider(
              min: 13,
              max: 34,
              divisions: 21,
              value: s.fontSize,
              onChanged: (v) {
                s.fontSize = v;
                setLocal(() {});
                setState(() {});
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fontSize = App.I.settings.fontSize;
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      appBar: _readingMode
          ? null
          : AppBar(
              title: Text(selecting ? '${_selected.length} selecionado(s)' : '${_b.name} $_chapter'),
              leading: selecting
                  ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_selected.clear))
                  : null,
              actions: selecting
                  ? null
                  : [
                      IconButton(
                          tooltip: 'Ouvir capítulo',
                          icon: const Icon(Icons.headphones),
                          onPressed: _audio.state == AudioState.idle ? () => _listen() : null),
                      IconButton(
                          tooltip: 'Fonte', icon: const Icon(Icons.format_size), onPressed: _fontDialog),
                      IconButton(
                          tooltip: 'Modo leitura',
                          icon: const Icon(Icons.chrome_reader_mode_outlined),
                          onPressed: _toggleReadingMode),
                      IconButton(
                        tooltip: 'Ver no PDF',
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: () => openBiblePdf(context,
                            book: _book, chapter: _chapter, page: _info?.pdfPage),
                      ),
                    ],
            ),
      floatingActionButton: _readingMode
          ? FloatingActionButton.small(
              onPressed: _toggleReadingMode,
              child: const Icon(Icons.fullscreen_exit),
            )
          : null,
      bottomNavigationBar: selecting
          ? _selectionBar()
          : _audio.state != AudioState.idle
              ? _playerBar(t)
              : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _verses.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: '${_b.name} $_chapter ainda não está indexado',
                    message: 'Leia este capítulo pelo PDF importado. Cópia, marcações e notas '
                        'dependem do texto indexado.',
                    action: FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Abrir no PDF'),
                      onPressed: () => openBiblePdf(context, book: _book, chapter: _chapter),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (_info?.isSuspect ?? false)
                        Card(
                          color: Colors.orange.withValues(alpha: 0.15),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                                'Atenção: este capítulo apresentou sinais de erro na extração do PDF. '
                                'Confira o texto no PDF antes de copiar ou compartilhar.'),
                          ),
                        ),
                      Center(
                        child: Text(_b.name.toUpperCase(),
                            style: t.textTheme.labelLarge
                                ?.copyWith(letterSpacing: 2, color: AppColors.gold)),
                      ),
                      Center(
                        child: Text('$_chapter',
                            style: t.textTheme.displaySmall?.copyWith(fontFamily: 'serif')),
                      ),
                      const SizedBox(height: 12),
                      for (final v in _verses) _verseTile(v, fontSize, t),
                      const SizedBox(height: 24),
                      Row(children: [
                        if (!(_book == 1 && _chapter == 1))
                          OutlinedButton.icon(
                              onPressed: () {
                                _audio.stop();
                                _go(-1);
                              },
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Anterior')),
                        const Spacer(),
                        if (!(_book == 66 && _chapter == 22))
                          FilledButton.icon(
                              onPressed: () {
                                _audio.stop();
                                _go(1);
                              },
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Próximo')),
                      ]),
                    ]),
                  ),
      ),
    );
  }

  Widget _verseTile(Verse v, double fontSize, ThemeData t) {
    final mark = _marks[v.id];
    final selected = _selected.contains(v.verse);
    final h = _highlight;
    final targeted = h != null && v.verse >= h && v.verse <= (_highlightEnd ?? h);
    Color? bg;
    final reading = _audio.state != AudioState.idle && _audio.current == v.verse;
    if (selected) {
      bg = t.colorScheme.primary.withValues(alpha: 0.18);
    } else if (reading) {
      bg = AppColors.gold.withValues(alpha: 0.30);
    } else if (mark?.color != null) {
      bg = AppColors.highlights[mark!.color! % AppColors.highlights.length].withValues(alpha: 0.45);
    } else if (targeted) {
      bg = AppColors.gold.withValues(alpha: 0.22);
    }
    return InkWell(
      key: _keys[v.verse],
      onTap: () => setState(() => selected ? _selected.remove(v.verse) : _selected.add(v.verse)),
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '${v.verse} ',
              style: TextStyle(
                  fontSize: fontSize * 0.65, color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
            TextSpan(text: v.text),
            if (_favs.contains('${v.id}'))
              const WidgetSpan(child: Icon(Icons.star, size: 14, color: AppColors.gold)),
            if (mark?.note != null)
              WidgetSpan(
                child: GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(v.ref.label),
                      content: Text(mark!.note!),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.gold),
                  ),
                ),
              ),
          ]),
          style: TextStyle(fontSize: fontSize, height: 1.55, fontFamily: 'serif'),
        ),
      ),
    );
  }

  Widget _selectionBar() => BottomAppBar(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          IconButton(
              tooltip: 'Ouvir a partir daqui',
              icon: const Icon(Icons.headphones),
              onPressed: () => _listen(from: _selectedVerses.first.verse)),
          IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: _copy),
          IconButton(tooltip: 'Compartilhar (WhatsApp)', icon: const Icon(Icons.share), onPressed: _share),
          IconButton(tooltip: 'Imagem para compartilhar', icon: const Icon(Icons.image_outlined), onPressed: _shareImage),
          IconButton(tooltip: 'Favorito', icon: const Icon(Icons.star_border), onPressed: _toggleFavorite),
          PopupMenuButton<int>(
            tooltip: 'Marcar',
            icon: const Icon(Icons.border_color_outlined),
            onSelected: (c) => _mark(c < 0 ? null : c),
            itemBuilder: (_) => [
              for (var i = 0; i < AppColors.highlights.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    CircleAvatar(radius: 10, backgroundColor: AppColors.highlights[i]),
                    const SizedBox(width: 10),
                    Text('Cor ${i + 1}'),
                  ]),
                ),
              const PopupMenuItem(value: -1, child: Text('Remover marcação')),
            ],
          ),
          IconButton(tooltip: 'Anotação', icon: const Icon(Icons.edit_note), onPressed: _note),
        ]),
      );

  Widget _playerBar(ThemeData t) {
    final playing = _audio.state == AudioState.playing;
    return BottomAppBar(
      child: Row(children: [
        IconButton.filled(
          tooltip: playing ? 'Pausar' : 'Continuar',
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          onPressed: playing ? _audio.pause : _audio.resume,
        ),
        IconButton(tooltip: 'Parar', icon: const Icon(Icons.stop), onPressed: _audio.stop),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _audio.current == null ? '${_b.name} $_chapter' : '${_b.name} $_chapter:${_audio.current}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Velocidade',
          initialValue: _audio.speed,
          onSelected: _setSpeed,
          itemBuilder: (_) => [for (final s in audioSpeeds.keys) PopupMenuItem(value: s, child: Text(s))],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_audio.speed, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        IconButton(
          tooltip: _autoNext ? 'Seguir para o próximo capítulo: ligado' : 'Seguir para o próximo capítulo: desligado',
          icon: Icon(Icons.playlist_play, color: _autoNext ? AppColors.gold : t.disabledColor),
          onPressed: () async {
            setState(() => _autoNext = !_autoNext);
            (await SharedPreferences.getInstance()).setBool('audioAutoNext', _autoNext);
            if (mounted) {
              showSnack(context, _autoNext ? 'Ao terminar, segue para o próximo capítulo' : 'Para ao fim do capítulo');
            }
          },
        ),
      ]),
    );
  }
}
