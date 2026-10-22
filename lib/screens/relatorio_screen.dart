import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ccb_relatorio.dart';
import '../services/rel_nearby.dart';
import '../theme.dart';
import '../widgets/directions.dart';
import 'my_places_screen.dart';

enum _Mode { perto, cidade, nome }

const List<int> _raios = [2, 5, 10, 20, 30, 50];

/// Pesquisa de casas de oração e horários de culto no relatório do site da CCB.
class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});
  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  final _api = CcbRelatorio();
  final _search = TextEditingController();
  late SharedPreferences _prefs;
  RelGeo? _geo;

  _Mode _mode = _Mode.perto;
  final Set<String> _tipos = {};
  final Set<int> _dias = {};
  final Set<String> _periodos = {};
  RelFilter get _filter => RelFilter(tipos: _tipos, dias: _dias, periodos: _periodos);

  // Por cidade / por nome
  List<RelOption> _paises = [], _estados = [], _cidades = [];
  String? _pais, _estado, _cidade;
  RelPage? _page;
  int _pagina = 1;

  // Perto de mim
  int _raio = 5;
  int _gen = 0;
  String? _status;
  String? _ondeEstou;
  final List<NearbyPlace> _near = [];
  final List<RelPlace> _semLocal = [];
  final Map<String, List<RelPlace>> _cityCache = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _gen++;
    _api.close();
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _prefs = await SharedPreferences.getInstance();
    _geo = RelGeo(_prefs);
    _raio = _prefs.getInt('relRaio') ?? 5;
    final saved = _prefs.getString('relModo');
    _mode = _Mode.values.where((m) => m.name == saved).firstOrNull ?? _Mode.perto;
    if (mounted) setState(() {});
    if (_mode == _Mode.perto) {
      _nearby();
    } else {
      _loadPaises();
    }
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await f();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
      return null;
    } on Object {
      if (mounted) setState(() => _error = 'Não foi possível consultar o site da CCB. Verifique a internet e tente de novo.');
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setMode(_Mode m) {
    setState(() {
      _mode = m;
      _page = null;
      _error = null;
    });
    _prefs.setString('relModo', m.name);
    if (m == _Mode.perto) {
      _nearby();
    } else {
      _gen++; // interrompe a busca por proximidade
      if (_paises.isEmpty) _loadPaises();
    }
  }

  void _filtersChanged() {
    _cityCache.clear();
    if (_mode == _Mode.perto) _nearby();
  }

  // ---------------------------------------------------------------- perto de mim

  Future<void> _nearby() async {
    final gen = ++_gen;
    bool alive() => mounted && gen == _gen;
    setState(() {
      _near.clear();
      _semLocal.clear();
      _error = null;
      _loading = true;
      _status = 'Obtendo sua localização…';
    });
    try {
      final geo = _geo!;
      final me = await geo.locate();
      if (!alive()) return;
      setState(() => _status = 'Identificando sua cidade…');
      final (estNames, cityNames) = await geo.whereIs(me);
      if (_paises.isEmpty) _paises = await _api.paises();
      final br = _paises.where((o) => o.text.toLowerCase() == 'brasil').firstOrNull;
      if (br == null) throw StateError('Lista de países indisponível no site.');
      final estados = await _api.estados(br.value);
      final est = matchOption(estados, estNames);
      if (est == null) throw StateError('Não encontrei seu estado no relatório. Use a pesquisa por cidade.');
      final cidades = await _api.cidades(est.value);
      final home = matchOption(cidades, cityNames);
      if (home == null) throw StateError('Não encontrei sua cidade no relatório. Use a pesquisa por cidade.');
      if (!alive()) return;
      final uf = ufOf(est.text);
      setState(() => _ondeEstou = '${home.text} - $uf');

      // Cidades a consultar: a sua e, para raios maiores, as vizinhas dentro do raio.
      final targets = <(RelOption, double)>[(home, 0)];
      if (_raio >= 10) {
        var i = 0;
        for (final c in cidades) {
          i++;
          if (c.value == home.value) continue;
          if (!alive()) return;
          setState(() => _status = 'Localizando cidades vizinhas ($i de ${cidades.length})…');
          final center = await geo.geocode('c:${c.value}', '${c.text}, $uf, Brasil');
          final d = center?.kmTo(me);
          // Margem de 10 km: o centro da cidade pode estar fora do raio e a igreja dentro.
          if (d != null && d <= _raio + 10) targets.add((c, d));
        }
        targets.sort((a, b) => a.$2.compareTo(b.$2));
      }

      for (final (city, _) in targets) {
        if (!alive()) return;
        setState(() => _status = 'Buscando casas de oração em ${city.text}…');
        final key = '${est.value}/${city.value}';
        final places = _cityCache[key] ??
            (_cityCache[key] = await allPlaces(_api, br.value, est.value, city.value, _filter).toList());
        var n = 0;
        for (final p in places) {
          if (!alive()) return;
          n++;
          if (n % 5 == 0) setState(() => _status = 'Calculando distâncias em ${city.text} ($n de ${places.length})…');
          final g = p.address.isEmpty ? null : await geo.geocode('p:${p.id}', '${p.address}, ${p.city}');
          final km = g?.kmTo(me);
          if (km == null) {
            if (city.value == home.value) _semLocal.add(p);
          } else if (km <= _raio) {
            _near
              ..add(NearbyPlace(p, km))
              ..sort((a, b) => a.km!.compareTo(b.km!));
          }
        }
        setState(() {});
      }
      if (alive()) setState(() => _status = null);
    } on StateError catch (e) {
      if (alive()) setState(() => _error = e.message);
    } on Object {
      if (alive()) {
        setState(() => _error = 'Não foi possível concluir a busca. Verifique a internet e a localização e tente de novo.');
      }
    } finally {
      if (alive()) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------- por cidade / nome

  Future<void> _loadPaises() async {
    final p = await _guard(_api.paises);
    if (p == null || !mounted) return;
    setState(() => _paises = p);
    final saved = _prefs.getString('relPais');
    final br = p.where((o) => o.value == saved).firstOrNull ?? p.where((o) => o.text.toLowerCase() == 'brasil').firstOrNull;
    if (br != null) await _setPais(br.value, restore: true);
  }

  Future<void> _setPais(String v, {bool restore = false}) async {
    setState(() {
      _pais = v;
      _estado = _cidade = null;
      _estados = _cidades = [];
    });
    _prefs.setString('relPais', v);
    final e = await _guard(() => _api.estados(v));
    if (e == null || !mounted) return;
    setState(() => _estados = e);
    final saved = restore ? _prefs.getString('relEstado') : null;
    if (saved != null && e.any((o) => o.value == saved)) await _setEstado(saved, restore: true);
  }

  Future<void> _setEstado(String v, {bool restore = false}) async {
    setState(() {
      _estado = v;
      _cidade = null;
      _cidades = [];
    });
    _prefs.setString('relEstado', v);
    final c = await _guard(() => _api.cidades(v));
    if (c == null || !mounted) return;
    setState(() => _cidades = c);
    final saved = restore ? _prefs.getString('relCidade') : null;
    if (saved != null && c.any((o) => o.value == saved)) setState(() => _cidade = saved);
  }

  Future<void> _run(int pagina) async {
    if (_mode == _Mode.nome && _search.text.trim().length < 3) {
      setState(() => _error = 'Digite pelo menos 3 letras do nome ou bairro.');
      return;
    }
    if (_mode == _Mode.cidade && _pais == null) return;
    if (_cidade != null) _prefs.setString('relCidade', _cidade!);
    final r = await _guard(() => _mode == _Mode.nome
        ? _api.localidades(_search.text.trim(), pagina: pagina)
        : _api.servicos(pais: _pais!, estado: _estado ?? '', cidade: _cidade ?? '', filter: _filter, pagina: pagina));
    if (r != null && mounted) {
      setState(() {
        _page = r;
        _pagina = pagina;
      });
    }
  }

  // ---------------------------------------------------------------- detalhe

  Future<void> _detail(RelPlace p) async {
    final d = await _guard(() => _api.detalhe(p.id));
    if (!mounted) return;
    final sections = d ?? const <RelSection>[];
    final query = [p.address, p.city].where((s) => s.isNotEmpty).join(', ');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Text(p.name, style: Theme.of(ctx).textTheme.titleLarge),
          if (p.code.isNotEmpty) Text(p.code, style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              icon: const Icon(Icons.directions),
              label: const Text('Como chegar'),
              onPressed: () => showDirectionsChooser(context, query),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver no mapa'),
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ]),
          SavePlaceButtons(place: p, sections: sections),
          if (d == null)
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('Detalhes indisponíveis no momento.')),
          for (final s in sections.where((s) => s.title.isNotEmpty && s.title != p.name.split(' - ').first)) ...[
            const SizedBox(height: 12),
            Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            for (final l in s.lines)
              if (RegExp(r'^\+?[\d\s()\-]{8,}$').hasMatch(l))
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${l.replaceAll(RegExp(r'[^\d+]'), '')}')),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [const Icon(Icons.call, size: 18), const SizedBox(width: 6), Text(l)]),
                  ),
                )
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l)),
          ],
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- interface

  Widget _dropdown(String label, List<RelOption> items, String? value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: items.any((o) => o.value == value) ? value : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: [
          for (final o in items) DropdownMenuItem(value: o.value, child: Text(o.text, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: items.isEmpty ? null : (v) => v == null ? null : onChanged(v),
      );

  Widget _filters() => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          _tipos.isEmpty && _dias.isEmpty && _periodos.isEmpty
              ? 'Filtros: todos os cultos'
              : 'Filtros: ${[..._tipos, ..._dias.map((d) => relDias[d - 1]), ..._periodos].join(', ')}',
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final tc in relTiposCulto)
              FilterChip(
                label: Text(tc),
                selected: _tipos.contains(tc),
                onSelected: (s) {
                  setState(() => s ? _tipos.add(tc) : _tipos.remove(tc));
                  _filtersChanged();
                },
              ),
          ]),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (var i = 0; i < relDias.length; i++)
              FilterChip(
                label: Text(relDias[i]),
                selected: _dias.contains(i + 1),
                onSelected: (s) {
                  setState(() => s ? _dias.add(i + 1) : _dias.remove(i + 1));
                  _filtersChanged();
                },
              ),
          ]),
          Wrap(spacing: 6, children: [
            for (final p in relPeriodos)
              FilterChip(
                label: Text(p),
                selected: _periodos.contains(p),
                onSelected: (s) {
                  setState(() => s ? _periodos.add(p) : _periodos.remove(p));
                  _filtersChanged();
                },
              ),
          ]),
          const SizedBox(height: 8),
        ],
      );

  Widget _placeTile(RelPlace p, {double? km}) => Card(
        child: ListTile(
          leading: const Icon(Icons.place_outlined, color: AppColors.navy),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text([p.address, p.city].where((s) => s.isNotEmpty).join('\n')),
          isThreeLine: p.address.isNotEmpty && p.city.isNotEmpty,
          trailing: km == null
              ? null
              : Text('${km.toStringAsFixed(1).replaceAll('.', ',')} km',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          onTap: () => _detail(p),
        ),
      );

  List<Widget> _pertoBody(ThemeData t) => [
        Row(children: [
          const Icon(Icons.my_location, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(_ondeEstou == null ? 'Sua localização' : 'Perto de você em $_ondeEstou')),
        ]),
        Row(children: [
          const Text('Raio:'),
          Expanded(
            child: Slider(
              value: _raios.indexOf(_raio).clamp(0, _raios.length - 1).toDouble(),
              min: 0,
              max: _raios.length - 1.0,
              divisions: _raios.length - 1,
              label: '$_raio km',
              onChanged: (v) => setState(() => _raio = _raios[v.round()]),
              onChangeEnd: (_) {
                _prefs.setInt('relRaio', _raio);
                _nearby();
              },
            ),
          ),
          Text('$_raio km', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        if (_raio >= 10)
          Text('Inclui cidades vizinhas. A primeira busca pode demorar; depois fica guardada no celular.',
              style: t.textTheme.bodySmall),
        if (_status != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_status!)),
        if (_near.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('${_near.length} casa(s) de oração até $_raio km', style: t.textTheme.bodySmall),
          ),
        for (final n in _near) _placeTile(n.place, km: n.km),
        if (!_loading && _near.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nenhuma casa de oração encontrada até $_raio km. Aumente o raio.', textAlign: TextAlign.center),
          ),
        if (_semLocal.isNotEmpty && !_loading) ...[
          const SizedBox(height: 8),
          Text('Na sua cidade, sem distância calculada:', style: t.textTheme.titleSmall),
          for (final p in _semLocal) _placeTile(p),
        ],
      ];

  List<Widget> _cidadeBody() => [
        _dropdown('País', _paises, _pais, _setPais),
        const SizedBox(height: 8),
        _dropdown('Estado', _estados, _estado, _setEstado),
        const SizedBox(height: 8),
        _dropdown('Cidade', _cidades, _cidade, (v) => setState(() => _cidade = v)),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Pesquisar cultos'),
          onPressed: _pais == null || _loading ? null : () => _run(1),
        ),
      ];

  List<Widget> _pageBody(ThemeData t) {
    final page = _page;
    if (page == null) return const [];
    return [
      if (page.info != null)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(page.info!, style: t.textTheme.bodySmall)),
      if (page.places.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum resultado.')),
      for (final p in page.places) _placeTile(p),
      if (page.places.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton.icon(
            onPressed: _pagina > 1 && !_loading ? () => _run(_pagina - 1) : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
          ),
          Text('Página $_pagina'),
          TextButton.icon(
            onPressed: page.hasNext && !_loading ? () => _run(_pagina + 1) : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Próxima'),
          ),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cultos e casas de oração'),
        actions: [
          if (_mode == _Mode.perto) IconButton(onPressed: _loading ? null : _nearby, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<_Mode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Mode.perto, icon: Icon(Icons.near_me_outlined), label: Text('Perto')),
            ButtonSegment(value: _Mode.cidade, icon: Icon(Icons.place_outlined), label: Text('Cidade')),
            ButtonSegment(value: _Mode.nome, icon: Icon(Icons.search), label: Text('Nome')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => _setMode(s.first),
        ),
        const SizedBox(height: 8),
        if (_mode != _Mode.nome) _filters(),
        if (_mode == _Mode.nome)
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(1),
            decoration: InputDecoration(
              labelText: 'Casa de oração ou bairro',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _run(1)),
            ),
          ),
        if (_mode == _Mode.cidade) ..._cidadeBody(),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
          ),
        if (_mode == _Mode.perto) ..._pertoBody(t) else ..._pageBody(t),
        const SizedBox(height: 12),
        Text(
          'Dados do relatório do site oficial da Congregação Cristã no Brasil (precisa de internet). '
          'Distâncias aproximadas, calculadas pelo endereço.',
          style: t.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
