import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/places_repository.dart';

/// Opções de antecedência do lembrete (minutos).
const Map<int, String> remindOptions = {15: '15 min antes', 30: '30 min antes', 60: '1 hora antes', 120: '2 horas antes'};

/// Lembretes semanais dos cultos das casas de oração salvas.
class CultoReminders {
  CultoReminders._();
  static final instance = CultoReminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
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
    );
    _ready = true;
  }

  /// Pede permissão de notificação (Android 13+). Devolve false se negada.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Refaz todos os lembretes a partir das casas salvas.
  Future<int> reschedule(List<SavedPlace> places) async {
    await _init();
    await _plugin.cancelAll();
    var count = 0;
    final now = tz.TZDateTime.now(tz.local);
    for (final p in places) {
      final minutes = p.remindMinutes;
      if (minutes == null) continue;
      final cultos = p.cultos;
      for (var i = 0; i < cultos.length; i++) {
        final c = cultos[i];
        final next = c.nextAfter(DateTime(now.year, now.month, now.day, now.hour, now.minute));
        var when = tz.TZDateTime(tz.local, next.year, next.month, next.day, c.hour, c.minute)
            .subtract(Duration(minutes: minutes));
        if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
        await _plugin.zonedSchedule(
          id: reminderId(p.place.id, i),
          title: '${c.kind} às ${c.time}',
          body: '${p.place.name} · ${p.address}',
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('cultos', 'Lembretes de culto',
                channelDescription: 'Aviso antes dos cultos das casas de oração salvas',
                importance: Importance.high,
                priority: Priority.high),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        count++;
      }
    }
    return count;
  }
}

/// Id estável e único por casa de oração + horário.
int reminderId(String placeId, int index) => (placeId.hashCode & 0xFFFFFF) * 64 + index;
