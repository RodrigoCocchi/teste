import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apps de rota oferecidos em "Como chegar". [primary] abre o app instalado;
/// [fallback] (site) é usado quando o app não está no celular.
class DirectionsApp {
  const DirectionsApp(this.name, this.icon, this.primary, [this.fallback]);
  final String name;
  final IconData icon;
  final Uri Function(String address) primary;
  final Uri Function(String address)? fallback;
}

final List<DirectionsApp> directionsApps = [
  DirectionsApp(
    'Google Maps',
    Icons.map,
    (a) => Uri.parse('google.navigation:q=${Uri.encodeComponent(a)}'),
    (a) => Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': a}),
  ),
  DirectionsApp(
    'Waze',
    Icons.navigation,
    (a) => Uri.https('waze.com', '/ul', {'q': a, 'navigate': 'yes'}),
  ),
  DirectionsApp(
    'Uber',
    Icons.local_taxi,
    (a) => Uri.https('m.uber.com', '/ul/', {'action': 'setPickup', 'pickup': 'my_location', 'dropoff[formatted_address]': a}),
  ),
  DirectionsApp(
    'Outro app de mapas',
    Icons.apps,
    // O Android mostra a lista de apps de mapa instalados.
    (a) => Uri.parse('geo:0,0?q=${Uri.encodeComponent(a)}'),
  ),
];

Future<void> _open(BuildContext context, DirectionsApp app, String address) async {
  var ok = false;
  try {
    ok = await launchUrl(app.primary(address), mode: LaunchMode.externalApplication);
  } on Object {
    ok = false;
  }
  if (!ok && app.fallback != null) {
    ok = await launchUrl(app.fallback!(address), mode: LaunchMode.externalApplication);
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o ${app.name}.')));
  }
}

/// Pergunta qual app usar para chegar ao endereço.
Future<void> showDirectionsChooser(BuildContext context, String address) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Abrir rota com', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(address, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          for (final app in directionsApps)
            ListTile(
              leading: Icon(app.icon),
              title: Text(app.name),
              onTap: () {
                Navigator.pop(ctx);
                _open(context, app, address);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
