import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_reminders.dart';
import '../services/app_services.dart';
import '../services/profile.dart';
import '../services/reminders.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';

/// Perfil pessoal: nome, comum e dados do batismo (tudo opcional).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _comum = TextEditingController();
  final _church = TextEditingController();
  final _minister = TextEditingController();
  DateTime? _baptism;
  bool _remind = true;
  List<String> _places = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = Profile.load(await SharedPreferences.getInstance());
    final places = [for (final s in await App.I.places.all()) s.place.name];
    if (!mounted) return;
    setState(() {
      _name.text = p.name;
      _comum.text = p.comum;
      _church.text = p.baptismChurch;
      _minister.text = p.baptismMinister;
      _baptism = p.baptismDate;
      _remind = p.remindBaptism;
      _places = places;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _comum, _church, _minister]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final p = Profile(
      name: _name.text,
      comum: _comum.text,
      baptismDate: _baptism,
      baptismChurch: _church.text,
      baptismMinister: _minister.text,
      remindBaptism: _remind,
    );
    await p.save(await SharedPreferences.getInstance());
    if (_baptism != null && _remind) await CultoReminders.instance.requestPermission();
    await refreshReminders();
    if (!mounted) return;
    final next = _baptism == null ? null : nextAnniversaries(_baptism!, DateTime.now()).firstOrNull;
    showSnack(
      context,
      next != null && _remind
          ? 'Perfil salvo. Próximo aniversário de batismo: ${two(next.$1.day)}/${two(next.$1.month)}/${next.$1.year} (${next.$2} ${next.$2 == 1 ? 'ano' : 'anos'}).'
          : 'Perfil salvo.',
    );
    Navigator.pop(context);
  }

  Future<void> _pickBaptism() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _baptism ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data do batismo',
    );
    if (d != null) setState(() => _baptism = d);
  }

  Widget _field(TextEditingController c, String label, {IconData? icon, TextCapitalization cap = TextCapitalization.words}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          textCapitalization: cap,
          decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon), border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = _baptism;
    final years = b == null ? null : DateTime.now().difference(b).inDays ~/ 365.2425;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Tudo é opcional e fica só no seu celular.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _field(_name, 'Nome', icon: Icons.person_outline),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _comum.text),
                optionsBuilder: (v) => _places.where((p) => p.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (v) => _comum.text = v,
                fieldViewBuilder: (ctx, ctrl, focus, _) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: ctrl,
                    focusNode: focus,
                    onChanged: (v) => _comum.text = v,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Comum', prefixIcon: Icon(Icons.home_outlined), border: OutlineInputBorder()),
                  ),
                ),
              ),
              const SectionTitle('Batismo'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.water_drop_outlined),
                title: Text(b == null ? 'Data do batismo' : '${two(b.day)}/${two(b.month)}/${b.year}'),
                subtitle: Text(b == null
                    ? 'Toque para escolher'
                    : years != null && years >= 1
                        ? '$years ${years == 1 ? 'ano' : 'anos'} de batismo'
                        : 'Menos de 1 ano de batismo'),
                trailing: b == null
                    ? const Icon(Icons.calendar_today)
                    : IconButton(tooltip: 'Limpar', icon: const Icon(Icons.clear), onPressed: () => setState(() => _baptism = null)),
                onTap: _pickBaptism,
              ),
              _field(_church, 'Igreja (comum) do batismo', icon: Icons.place_outlined),
              _field(_minister, 'Ministério do batismo (ancião)', icon: Icons.person_pin_outlined),
              if (b != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembrar o aniversário de batismo'),
                  subtitle: const Text('Aviso todo ano, às 8h do dia'),
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Salvar'), onPressed: _save),
            ]),
    );
  }
}
