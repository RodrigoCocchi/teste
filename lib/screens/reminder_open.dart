import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_services.dart';
import '../services/profile.dart';
import '../services/share_builders.dart';
import '../widgets/share_card.dart';

/// Abre o cartão (com compartilhar) do aviso tocado: culto, agenda ou escala.
Future<void> openReminderPayload(NavigatorState nav, String payload) async {
  final app = App.I;
  final parts = payload.split(':');
  ShareCardData? data;
  switch (parts.first) {
    case 'culto' when parts.length >= 3:
      final p = await app.places.get(parts[1]);
      final i = int.tryParse(parts[2]) ?? 0;
      final cultos = p?.cultos ?? const [];
      if (p != null && i < cultos.length) {
        final c = cultos[i];
        data = cultoShare(p, c, c.nextAfter(DateTime.now().subtract(const Duration(hours: 3))));
      }
    case 'event':
      final e = await app.agenda.get(int.tryParse(parts[1]) ?? -1);
      final at = e?.nextAfter(DateTime.now().subtract(const Duration(hours: 3))) ?? e?.start;
      if (e != null && at != null) data = eventShare(e, at);
    case 'baptism':
      final p = Profile.load(await SharedPreferences.getInstance());
      data = baptismShare(p, int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1);
    case 'duty':
      final d = await app.organ.duty(int.tryParse(parts[1]) ?? -1);
      if (d != null) {
        final name = (await app.organ.organists()).where((o) => o.id == d.organistId).firstOrNull?.name ?? '';
        data = dutyShare(d, name);
      }
  }
  if (data != null) {
    await nav.push(MaterialPageRoute<void>(builder: (_) => ShareCardScreen(data: data!, title: 'Lembrete')));
  }
}
