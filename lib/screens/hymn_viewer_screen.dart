import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../data/hymn_repository.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pdf_page_viewer.dart';
import 'documents_screen.dart';
import 'hymn_mapping_screen.dart';
import 'nav.dart';

/// Partitura do hino no PDF importado (Dó ou órgão), com zoom, tela cheia e
/// navegação entre hinos.
class HymnViewerScreen extends StatefulWidget {
  const HymnViewerScreen({super.key, required this.number});
  final int number;
  @override
  State<HymnViewerScreen> createState() => _HymnViewerScreenState();
}

class _HymnViewerScreenState extends State<HymnViewerScreen> {
  late int _number = widget.number;
  Hymn? _hymn;
  bool _fav = false;
  int? _targetPage;
  int _page = 1;
  int _count = 0;
  bool _full = false;
  bool _ready = false;
  var _viewer = GlobalKey<PdfPageViewerState>();

  String get _doc => App.I.settings.hymnDoc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_full) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    final app = App.I;
    final hymn = await app.hymns.get(_number);
    final pages = await app.hymns.manualPages(_doc);
    final target = HymnRepository.resolvePage(_number, pages, app.settings.linearMapping(_doc));
    final fav = await app.user.isFavorite('hymn', '$_number');
    app.settings.lastHymn = _number;
    app.user.addHistory('hymn', '$_number', hymn.display);
    if (!mounted) return;
    final firstLoad = !_ready;
    setState(() {
      _hymn = hymn;
      _fav = fav;
      _targetPage = target;
      _ready = true;
      if (firstLoad) _page = target ?? app.settings.pdfPage(_doc);
    });
    if (!firstLoad && target != null) _viewer.currentState?.jumpTo(target);
  }

  void _step(int delta) {
    final n = _number + delta;
    if (n < 1 || n > Hymns.total) return;
    setState(() => _number = n);
    _load();
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    SystemChrome.setEnabledSystemUIMode(_full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  Future<void> _menu(String v) async {
    final app = App.I;
    switch (v) {
      case 'map':
        await app.hymns.setPage(_number, _doc, _page);
        if (mounted) showSnack(context, '${Hymn.labelFor(_number)} → página $_page (${Hymns.docLabel(_doc)})');
        _load();
      case 'title':
        final ctrl = TextEditingController(text: _hymn?.title ?? '');
        final t = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Título do ${Hymn.labelFor(_number)}'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Como impresso no hinário'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
            ],
          ),
        );
        if (t != null) {
          await app.hymns.setTitle(_number, t);
          _load();
        }
      case 'audio':
        final files = await FilePicker.pickFiles(type: FileType.audio);
        final src = files.isEmpty ? null : files.first.path;
        if (src == null) return;
        final dir = Directory(app.documents.audioDir);
        await dir.create(recursive: true);
        final dest = p.join(dir.path, 'hino_$_number${p.extension(src)}');
        await File(src).copy(dest);
        await app.hymns.setAudio(_number, dest);
        if (mounted) showSnack(context, 'Áudio associado ao ${Hymn.labelFor(_number)}');
        _load();
      case 'play':
        final path = _hymn?.audioPath;
        if (path != null && File(path).existsSync()) {
          await SharePlus.instance.share(ShareParams(files: [XFile(path)], title: _hymn!.display));
        }
      case 'unaudio':
        await app.hymns.setAudio(_number, null);
        _load();
      case 'doc':
        app.settings.hymnDoc = _doc == 'do' ? 'orgao' : 'do';
        setState(() {
          _ready = false;
          _viewer = GlobalKey<PdfPageViewerState>();
        });
        _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    final doc = app.documents.info(DocKind.hymnal(_doc));
    final title = _hymn?.display ?? Hymn.labelFor(_number);
    return Scaffold(
      appBar: _full
          ? null
          : AppBar(
              title: Text(title, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: 'Favorito',
                  icon: Icon(_fav ? Icons.star : Icons.star_border, color: AppColors.gold),
                  onPressed: () async {
                    final v = await app.user.toggleFavorite('hymn', '$_number', title);
                    setState(() => _fav = v);
                  },
                ),
                IconButton(tooltip: 'Tela cheia', icon: const Icon(Icons.fullscreen), onPressed: _toggleFull),
                PopupMenuButton<String>(
                  onSelected: _menu,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'doc', child: Text('Trocar para ${_doc == 'do' ? 'órgão' : 'Dó'}')),
                    PopupMenuItem(value: 'map', child: Text('Esta página (p. $_page) é o ${Hymn.labelFor(_number)}')),
                    const PopupMenuItem(value: 'title', child: Text('Editar título')),
                    const PopupMenuItem(value: 'audio', child: Text('Associar MP3 local')),
                    if (_hymn?.audioPath != null) ...[
                      const PopupMenuItem(value: 'play', child: Text('Abrir áudio associado')),
                      const PopupMenuItem(value: 'unaudio', child: Text('Remover áudio')),
                    ],
                  ],
                ),
              ],
            ),
      floatingActionButton: _full
          ? FloatingActionButton.small(onPressed: _toggleFull, child: const Icon(Icons.fullscreen_exit))
          : null,
      bottomNavigationBar: _full
          ? null
          : BottomAppBar(
              child: Row(children: [
                TextButton.icon(
                  onPressed: _number > 1 ? () => _step(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
                Expanded(
                  child: Text(
                    doc == null ? '' : 'p. $_page${_count > 0 ? '/$_count' : ''} · ${_doc == 'do' ? 'Dó' : 'Órgão'}',
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton.icon(
                  onPressed: _number < Hymns.total ? () => _step(1) : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Próximo'),
                ),
              ]),
            ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : doc == null
              ? EmptyState(
                  icon: Icons.library_music_outlined,
                  title: '${Hymns.docLabel(_doc)} não importado',
                  message: 'Importe o PDF do hinário a partir do seu celular.',
                  action: FilledButton(
                      onPressed: () => push(context, const DocumentsScreen()),
                      child: const Text('Importar documentos')),
                )
              : Column(children: [
                  if (_targetPage == null && !_full)
                    MaterialBanner(
                      content: Text('A página do ${Hymn.labelFor(_number)} ainda não foi mapeada. '
                          'Navegue até a partitura e use o menu › "Esta página é o hino", '
                          'ou configure o mapeamento.'),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await push(context, const HymnMappingScreen());
                            _load();
                          },
                          child: const Text('Mapear'),
                        ),
                      ],
                    ),
                  if (_hymn?.audioPath != null && !_full)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.audiotrack, color: AppColors.gold),
                      title: Text('Áudio: ${p.basename(_hymn!.audioPath!)}'),
                      subtitle: const Text('Toque para abrir no reprodutor do celular'),
                      onTap: () => _menu('play'),
                    ),
                  Expanded(
                    child: PdfPageViewer(
                      key: _viewer,
                      path: doc.path,
                      initialPage: _page,
                      onLoaded: (n) => setState(() => _count = n),
                      onPageChanged: (pg) {
                        setState(() => _page = pg);
                        app.settings.setPdfPage(_doc, pg);
                      },
                    ),
                  ),
                ]),
    );
  }
}
