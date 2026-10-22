import 'package:shared_preferences/shared_preferences.dart';

/// Perfil pessoal (tudo opcional, fica só no aparelho).
class Profile {
  const Profile({this.name = '', this.comum = '', this.baptismDate, this.baptismChurch = '', this.baptismMinister = '', this.remindBaptism = true});
  final String name;
  final String comum;
  final DateTime? baptismDate;
  final String baptismChurch;
  final String baptismMinister; // ancião (ministério) que realizou o batismo
  final bool remindBaptism;

  static const keys = ['pfName', 'pfComum', 'pfBaptism', 'pfBaptismChurch', 'pfBaptismMinister', 'pfRemindBaptism'];

  static Profile load(SharedPreferences p) {
    final b = p.getString('pfBaptism');
    return Profile(
      name: p.getString('pfName') ?? '',
      comum: p.getString('pfComum') ?? '',
      baptismDate: b == null ? null : DateTime.tryParse(b),
      baptismChurch: p.getString('pfBaptismChurch') ?? '',
      baptismMinister: p.getString('pfBaptismMinister') ?? '',
      remindBaptism: p.getBool('pfRemindBaptism') ?? true,
    );
  }

  Future<void> save(SharedPreferences p) async {
    Future<void> put(String k, String v) => v.trim().isEmpty ? p.remove(k) : p.setString(k, v.trim());
    await put('pfName', name);
    await put('pfComum', comum);
    final b = baptismDate;
    await put('pfBaptism', b == null ? '' : '${b.year}-${_two(b.month)}-${_two(b.day)}');
    await put('pfBaptismChurch', baptismChurch);
    await put('pfBaptismMinister', baptismMinister);
    await p.setBool('pfRemindBaptism', remindBaptism);
  }

  /// Para o backup.
  Map<String, Object?> toJson() => {
        'name': name,
        'comum': comum,
        'baptism': baptismDate?.toIso8601String(),
        'baptismChurch': baptismChurch,
        'baptismMinister': baptismMinister,
        'remindBaptism': remindBaptism,
      };

  static Profile fromJson(Map j) => Profile(
        name: '${j['name'] ?? ''}',
        comum: '${j['comum'] ?? ''}',
        baptismDate: j['baptism'] == null ? null : DateTime.tryParse('${j['baptism']}'),
        baptismChurch: '${j['baptismChurch'] ?? ''}',
        baptismMinister: '${j['baptismMinister'] ?? ''}',
        remindBaptism: j['remindBaptism'] != false,
      );

  bool get isEmpty => name.isEmpty && comum.isEmpty && baptismDate == null && baptismChurch.isEmpty && baptismMinister.isEmpty;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Data do aniversário de batismo num ano (29/02 vira 28/02 em anos comuns).
DateTime anniversaryIn(DateTime baptism, int year) {
  final last = DateTime(year, baptism.month + 1, 0).day;
  return DateTime(year, baptism.month, baptism.day > last ? last : baptism.day);
}

/// Próximos aniversários de batismo (data, anos completos), a partir de hoje.
List<(DateTime, int)> nextAnniversaries(DateTime baptism, DateTime now, {int count = 3}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <(DateTime, int)>[];
  for (var y = now.year; out.length < count; y++) {
    final d = anniversaryIn(baptism, y);
    final years = y - baptism.year;
    if (years >= 1 && !d.isBefore(today)) out.add((d, years));
  }
  return out;
}

/// Hoje é aniversário de batismo? Devolve os anos, ou null.
int? baptismYearsToday(DateTime? baptism, DateTime now) {
  if (baptism == null) return null;
  final d = anniversaryIn(baptism, now.year);
  final years = now.year - baptism.year;
  return years >= 1 && d.month == now.month && d.day == now.day ? years : null;
}
