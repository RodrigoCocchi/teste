import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ccb_relatorio.dart';
import '../theme.dart';

/// Pesquisa de casas de oração e horários de culto no relatório do site da CCB.
class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});
  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  final _api = CcbRelatorio();
  final _search = TextEditingController();
  SharedPreferences? _prefs;

  List<RelOption> _paises = [], _estados = [], _cidades = [];
  String? _pais, _estado, _cidade;
  final Set<String> _tipos = {};
  int? _dia;
  String _periodo = '';

  RelPage? _page;
  int _pagina = 1;
  bool _byName = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _api.close();
    _search.dispose();
    super.dispose();
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await f();
    } on Object {
      if (mounted) setState(() => _error = 'Não foi possível consultar o site da CCB. Verifique a internet e tente de novo.');
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    _prefs = await SharedPreferences.getInstance();
    final p = await _guard(_api.paises);
    if (p == null || !mounted) return;
    setState(() => _paises = p);
    final saved = _prefs?.getString('relPais');
    final br = p.where((o) => o.value == saved).firstOrNull ??
        p.where((o) => o.text.toLowerCase().contains('brasil')).firstOrNull;
    if (br != null) await _setPais(br.value, restore: true);
  }

  Future<void> _setPais(String v, {bool restore = false}) async {
    setState(() {
      _pais = v;
      _estado = _cidade = null;
      _estados = _cidades = [];
    });
    _prefs?.setString('relPais', v);
    final e = await _guard(() => _api.estados(v));
    if (e == null || !mounted) return;
    setState(() => _estados = e);
    final saved = restore ? _prefs?.getString('relEstado') : null;
    if (saved != null && e.any((o) => o.value == saved)) await _setEstado(saved, restore: true);
  }

  Future<void> _setEstado(String v, {bool restore = false}) async {
    setState(() {
      _estado = v;
      _cidade = null;
      _cidades = [];
    });
    _prefs?.setString('relEstado', v);
    final c = await _guard(() => _api.cidades(v));
    if (c == null || !mounted) return;
    setState(() => _cidades = c);
    final saved = restore ? _prefs?.getString('relCidade') : null;
    if (saved != null && c.any((o) => o.value == saved)) {
      setState(() => _cidade = saved);
      await _run(1);
    }
  }

  Future<void> _run(int pagina) async {
    if (!_byName && _pais == null) return;
    if (_byName && _search.text.trim().length < 3) {
      setState(() => _error = 'Digite pelo menos 3 letras do nome ou bairro.');
      return;
    }
    if (!_byName && _cidade != null) _prefs?.setString('relCidade', _cidade!);
    final r = await _guard(() => _byName
        ? _api.localidades(_search.text.trim(), pagina: pagina)
        : _api.servicos(
            pais: _pais!,
            estado: _estado ?? '',
            cidade: _cidade ?? '',
            tipos: _tipos,
            dia: _dia,
            periodo: _periodo,
            pagina: pagina,
          ));
    if (r != null && mounted) {
      setState(() {
        _page = r;
        _pagina = pagina;
      });
    }
  }

  Future<void> _detail(RelRow row) async {
    final id = row.id;
    final d = id == null ? null : await _guard(() => _api.detalhe(id));
    if (!mounted) return;
    final title = row.cells.first;
    final pairs = d ?? [for (var i = 0; i < row.cells.length; i++) (_header(i), row.cells[i])];
    final address = pairs
        .where((p) => RegExp(r'endere|logradouro', caseSensitive: false).hasMatch(p.$1))
        .map((p) => p.$2)
        .firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final p in pairs)
            if (p.$2.isNotEmpty && p.$2 != title)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: p.$1.isEmpty
                    ? Text(p.$2)
                    : Text.rich(TextSpan(children: [
                        TextSpan(text: '${p.$1}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: p.$2),
                      ])),
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir no mapa'),
            onPressed: () => launchUrl(
              Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': address ?? 'Congregação Cristã no Brasil $title ${_cityName()}',
              }),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ]),
      ),
    );
  }

  String _cityName() => _cidades.where((c) => c.value == _cidade).firstOrNull?.text ?? '';
  String _header(int i) => _page != null && i < _page!.headers.length ? _page!.headers[i] : '';

  Widget _dropdown(String label, List<RelOption> items, String? value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: items.any((o) => o.value == value) ? value : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: [for (final o in items) DropdownMenuItem(value: o.value, child: Text(o.text, overflow: TextOverflow.ellipsis))],
        onChanged: items.isEmpty ? null : (v) => v == null ? null : onChanged(v),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório — Cultos')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.place_outlined), label: Text('Por cidade')),
            ButtonSegment(value: true, icon: Icon(Icons.search), label: Text('Por nome')),
          ],
          selected: {_byName},
          onSelectionChanged: (s) => setState(() {
            _byName = s.first;
            _page = null;
          }),
        ),
        const SizedBox(height: 12),
        if (_byName)
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(1),
            decoration: InputDecoration(
              labelText: 'Casa de oração, bairro ou cidade',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _run(1)),
            ),
          )
        else ...[
          _dropdown('País', _paises, _pais, _setPais),
          const SizedBox(height: 8),
          _dropdown('Estado', _estados, _estado, _setEstado),
          const SizedBox(height: 8),
          _dropdown('Cidade', _cidades, _cidade, (v) => setState(() => _cidade = v)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final tc in relTiposCulto)
              FilterChip(
                label: Text(tc),
                selected: _tipos.contains(tc),
                onSelected: (s) => setState(() => s ? _tipos.add(tc) : _tipos.remove(tc)),
              ),
          ]),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (var i = 0; i < relDias.length; i++)
              ChoiceChip(
                label: Text(relDias[i]),
                selected: _dia == i + 1,
                onSelected: (s) => setState(() => _dia = s ? i + 1 : null),
              ),
          ]),
          Wrap(spacing: 6, children: [
            for (final p in relPeriodos)
              ChoiceChip(
                label: Text(p),
                selected: _periodo == p,
                onSelected: (s) => setState(() => _periodo = s ? p : ''),
              ),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Pesquisar cultos'),
            onPressed: _pais == null || _loading ? null : () => _run(1),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
          ),
        if (page != null) ...[
          if (page.info != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(page.info!, style: t.textTheme.bodySmall)),
          if (page.rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum resultado.')),
          for (final r in page.rows)
            Card(
              child: ListTile(
                leading: const Icon(Icons.church_outlined, color: AppColors.navy),
                title: Text(r.cells.first, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text([
                  for (var i = 1; i < r.cells.length; i++)
                    if (r.cells[i].isNotEmpty) _header(i).isEmpty ? r.cells[i] : '${_header(i)}: ${r.cells[i]}',
                ].join('\n')),
                isThreeLine: r.cells.length > 2,
                onTap: () => _detail(r),
              ),
            ),
          if (page.rows.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(
                onPressed: _pagina > 1 && !_loading ? () => _run(_pagina - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text('Página $_pagina'),
              TextButton.icon(
                onPressed: !_loading ? () => _run(_pagina + 1) : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Próxima'),
              ),
            ]),
        ],
        const SizedBox(height: 12),
        Text('Dados consultados no relatório do site oficial da Congregação Cristã no Brasil '
            '(precisa de internet).', style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
