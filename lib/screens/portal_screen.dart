import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_services.dart';
import '../services/ccb_portal.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'relatorio_screen.dart';

/// Atalhos para o site oficial da CCB (abre no navegador).
class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});
  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  late PortalData _data = App.I.portal.cached;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final d = await App.I.portal.refresh();
      if (mounted) setState(() => _data = d);
      _error = null;
    } on Object {
      _error = 'Sem conexão com o site: usando os links guardados.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Não foi possível abrir: $url');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal CCB'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: t.textTheme.bodySmall)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.circle, color: Colors.red, size: 12),
                  const SizedBox(width: 8),
                  Text('Próximo Culto on-line', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ]),
                if (_data.nextCulto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 20),
                    child: Text(_data.nextCulto!, style: TextStyle(color: Colors.red.shade700, fontSize: 18)),
                  ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final b in cultoButtons)
                    OutlinedButton.icon(
                      icon: Icon(switch (b.key) {
                        'video' => Icons.play_circle_fill,
                        'libras' => Icons.sign_language,
                        'audio' => Icons.volume_up,
                        'telefone' => Icons.call,
                        _ => Icons.volunteer_activism,
                      }, color: switch (b.key) {
                        'video' => Colors.red,
                        'libras' => Colors.blue,
                        'audio' => Colors.green,
                        _ => AppColors.navy,
                      }),
                      label: Text(b.title),
                      onPressed: () => _open(_data.urlFor(b.key)),
                    ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.navy,
            child: ListTile(
              leading: const Icon(Icons.near_me, color: Colors.white, size: 32),
              title: const Text('Pesquisar cultos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Casas de oração e horários (relatório) dentro do app',
                  style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const RelatorioScreen())),
            ),
          ),
          for (final s in portalSections)
            Card(
              child: ListTile(
                leading: Icon(switch (s.key) {
                  'institucional' => Icons.account_balance,
                  'irmandade' => Icons.campaign_outlined,
                  'topicos' => Icons.menu_book_outlined,
                  'culto' => Icons.live_tv,
                  'relatorio' => Icons.fact_check_outlined,
                  _ => Icons.volunteer_activism_outlined,
                }, color: AppColors.navy, size: 32),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s.subtitle),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _open(_data.urlFor(s.key)),
              ),
            ),
          const SizedBox(height: 12),
          Text('Os links abrem o site oficial da Congregação Cristã no Brasil no navegador '
              '(precisa de internet).', style: t.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
