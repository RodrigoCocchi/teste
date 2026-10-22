import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/agenda_repository.dart';
import '../data/organ_repository.dart';
import '../data/places_repository.dart';

/// Opções de antecedência do lembrete dos cultos (minutos).
const Map<int, String> remindOptions = {15: '15 min antes', 30: '30 min antes', 60: '1 hora antes', 120: '2 horas antes'};

/// Um aviso a agendar.
class AlertSpec {
  const AlertSpec(this.id, this.title, this.body, this.when, this.payload, {this.repeat});
  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload; // culto:<placeId>:<i> | event:<id> | duty:<id>
  final DateTimeComponents? repeat;
}

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Id estável e único por casa de oração + horário (faixa 0 a 1.073.741.823).
int reminderId(String placeId, int index) => (placeId.hashCode & 0xFFFFFF) * 64 + index;
int eventAlertId(int eventId, int k) => 1200000000 + eventId * 10 + k;
int dutyAlertId(int dutyId, int k) => 1600000000 + dutyId * 10 + k;

/// Avisos semanais dos cultos de uma casa salva.
List<AlertSpec> placeAlerts(SavedPlace p, DateTime now) {
  final minutes = p.remindMinutes;
  if (minutes == null) return const [];
  final cultos = p.cultos;
  return [
    for (var i = 0; i < cultos.length; i++)
      () {
        final c = cultos[i];
        var when = c.nextAfter(now).subtract(Duration(minutes: minutes));
        if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
        return AlertSpec(reminderId(p.place.id, i), '${c.kind} às ${c.time}', '${p.place.name} · ${p.address}', when,
            'culto:${p.place.id}:$i',
            repeat: DateTimeComponents.dayOfWeekAndTime);
      }(),
  ];
}

/// Avisos de um compromisso da agenda.
List<AlertSpec> eventAlerts(AgendaEvent e, DateTime now) {
  final out = <AlertSpec>[];
  final repeat = switch (e.repeat) {
    'weekly' => DateTimeComponents.dayOfWeekAndTime,
    'monthly' => DateTimeComponents.dayOfMonthAndTime,
    _ => null,
  };
  for (var k = 0; k < e.alerts.length && k < 10; k++) {
    final m = e.alerts[k];
    // Próxima ocorrência cujo aviso ainda não passou.
    final occ = e.nextAfter(now.add(Duration(minutes: m)));
    if (occ == null) continue;
    final when = occ.subtract(Duration(minutes: m));
    final label = alertOptions[m] ?? '$m min';
    out.add(AlertSpec(
      eventAlertId(e.id!, k),
      '${e.displayTitle} ${repeat == null ? 'em $label' : 'às ${_hm(occ)}'}',
      [if (repeat == null) '${_two(occ.day)}/${_two(occ.month)} às ${_hm(occ)}', if (e.place.isNotEmpty) e.place].join(' · '),
      when,
      'event:${e.id}',
      repeat: repeat,
    ));
  }
  return out;
}

/// Avisos da escala da organista (só os próximos 60 dias).
List<AlertSpec> dutyAlerts(OrganDuty d, List<int> minutes, DateTime now) {
  if (d.id == null || d.at.isAfter(now.add(const Duration(days: 60)))) return const [];
  return [
    for (var k = 0; k < minutes.length && k < 10; k++)
      if (d.playAt.subtract(Duration(minutes: minutes[k])).isAfter(now))
        AlertSpec(
          dutyAlertId(d.id!, k),
          'Órgão: ${d.part} às ${_hm(d.playAt)}',
          [ '${_two(d.at.day)}/${_two(d.at.month)}', if (d.place.isNotEmpty) d.place].join(' · '),
          d.playAt.subtract(Duration(minutes: minutes[k])),
          'duty:${d.id}',
        ),
  ];
}

/// Avisos padrão da escala do órgão (minutos antes de começar a tocar).
const String organAlertsKey = 'organAlerts';
List<int> organAlertsFrom(SharedPreferences p) =>
    [for (final s in p.getStringList(organAlertsKey) ?? const ['1440', '120']) int.tryParse(s) ?? 60];

/// Agenda e entrega os lembretes (cultos, agenda e escala do órgão).
class CultoReminders {
  CultoReminders._();
  static final instance = CultoReminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Chamado quando a pessoa toca no aviso ou em "Compartilhar" (payload, se foi o botão).
  void Function(String payload, bool share)? onOpen;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(id));
    } on Object {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) onOpen?.call(p, r.actionId == 'share');
      },
    );
    _ready = true;
  }

  /// Se o app foi aberto por um aviso, devolve (payload, compartilhar).
  Future<(String, bool)?> launchPayload() async {
    await init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d?.didNotificationLaunchApp != true || r?.payload == null) return null;
    return (r!.payload!, r.actionId == 'share');
  }

  /// Pede permissão de notificação (Android 13+). Devolve false se negada.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Refaz todos os lembretes.
  Future<int> rescheduleAll({
    required List<SavedPlace> places,
    required List<AgendaEvent> events,
    required List<OrganDuty> myDuties,
    required List<int> organAlerts,
  }) async {
    await init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final specs = [
      for (final p in places) ...placeAlerts(p, now),
      for (final e in events) ...eventAlerts(e, now),
      for (final d in myDuties) ...dutyAlerts(d, organAlerts, now),
    ]..sort((a, b) => a.when.compareTo(b.when));
    var count = 0;
    // O Android limita os alarmes por app: agenda os mais próximos.
    for (final s in specs.take(400)) {
      try {
        await _plugin.zonedSchedule(
          id: s.id,
          title: s.title,
          body: s.body,
          scheduledDate: tz.TZDateTime.from(s.when, tz.local),
          payload: s.payload,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'lembretes',
              'Lembretes',
              channelDescription: 'Cultos, agenda e escala do órgão',
              importance: Importance.high,
              priority: Priority.high,
              actions: [AndroidNotificationAction('share', 'Compartilhar', showsUserInterface: true)],
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: s.repeat,
        );
        count++;
      } on Object catch (e) {
        debugPrint('Lembrete não agendado: $e');
      }
    }
    return count;
  }
}
