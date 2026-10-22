import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'reminders.dart';

/// Refaz todos os lembretes a partir dos dados salvos (cultos, agenda, escala).
Future<void> refreshReminders() async {
  try {
    final app = App.I;
    final prefs = await SharedPreferences.getInstance();
    final me = (await app.organ.organists()).where((o) => o.isMe).firstOrNull;
    final now = DateTime.now();
    await CultoReminders.instance.rescheduleAll(
      places: await app.places.all(),
      events: await app.agenda.all(),
      myDuties: me == null
          ? const []
          : [for (final d in await app.organ.duties(from: now)) if (d.organistId == me.id) d],
      organAlerts: organAlertsFrom(prefs),
    );
  } on Object {
    // Sem permissão ou serviço indisponível: os dados continuam salvos.
  }
}
