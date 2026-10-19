import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/text_utils.dart';
import 'ccb_relatorio.dart';

const Map<String, String> ufNames = {
  'AC': 'Acre', 'AL': 'Alagoas', 'AP': 'Amapá', 'AM': 'Amazonas', 'BA': 'Bahia', 'CE': 'Ceará',
  'DF': 'Distrito Federal', 'ES': 'Espírito Santo', 'GO': 'Goiás', 'MA': 'Maranhão', 'MT': 'Mato Grosso',
  'MS': 'Mato Grosso do Sul', 'MG': 'Minas Gerais', 'PA': 'Pará', 'PB': 'Paraíba', 'PR': 'Paraná',
  'PE': 'Pernambuco', 'PI': 'Piauí', 'RJ': 'Rio de Janeiro', 'RN': 'Rio Grande do Norte',
  'RS': 'Rio Grande do Sul', 'RO': 'Rondônia', 'RR': 'Roraima', 'SC': 'Santa Catarina', 'SP': 'São Paulo',
  'SE': 'Sergipe', 'TO': 'Tocantins',
};

String _norm(String s) => normalize(s)
    .replaceAll(RegExp(r'^(state of|estado de|estado do|estado da)\s+'), '')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Escolhe a opção cujo nome bate com algum dos textos (sem acento/maiúsculas).
RelOption? matchOption(List<RelOption> options, Iterable<String?> names) {
  for (final n in names) {
    if (n == null || n.trim().isEmpty) continue;
    final k = _norm(ufNames[n.trim().toUpperCase()] ?? n);
    final hit = options.where((o) => _norm(o.text) == k).firstOrNull;
    if (hit != null) return hit;
  }
  return null;
}

String ufOf(String estadoText) {
  final k = _norm(estadoText);
  return ufNames.entries.where((e) => _norm(e.value) == k).firstOrNull?.key ?? estadoText;
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat, lng;
  double kmTo(GeoPoint o) => Geolocator.distanceBetween(lat, lng, o.lat, o.lng) / 1000;
}

/// Localização do aparelho e conversão de endereços em coordenadas (pelo
/// serviço de mapas do próprio Android), com cache no aparelho.
class RelGeo {
  RelGeo(this._prefs);
  final SharedPreferences _prefs;
  final _geocoding = Geocoding();

  /// Pede permissão e devolve a posição atual. Lança [StateError] com a mensagem para o usuário.
  Future<GeoPoint> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização (GPS) do celular.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw StateError('Permita o acesso à localização para ver as igrejas mais próximas.');
    }
    final last = await Geolocator.getLastKnownPosition();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
      return GeoPoint(p.latitude, p.longitude);
    } on Object {
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      rethrow;
    }
  }

  /// Estado e cidade (nomes) da posição.
  Future<(List<String?>, List<String?>)> whereIs(GeoPoint p) async {
    final marks = await _geocoding.placemarkFromCoordinates(p.lat, p.lng);
    final m = marks.firstOrNull;
    if (m == null) return (<String?>[], <String?>[]);
    return (
      [m.administrativeArea, m.subAdministrativeArea],
      [m.subAdministrativeArea, m.locality, m.subLocality],
    );
  }

  /// Coordenadas de um endereço (guardadas para não consultar de novo).
  Future<GeoPoint?> geocode(String key, String query) async {
    final cached = _prefs.getString('geo:$key');
    if (cached != null) {
      if (cached.isEmpty) return null;
      final parts = cached.split(',');
      return GeoPoint(double.parse(parts[0]), double.parse(parts[1]));
    }
    try {
      final r = await _geocoding.locationFromAddress(query);
      final l = r.firstOrNull;
      await _prefs.setString('geo:$key', l == null ? '' : '${l.latitude},${l.longitude}');
      return l == null ? null : GeoPoint(l.latitude, l.longitude);
    } on Object catch (e) {
      // Endereço não encontrado fica guardado; falha de rede não.
      if ('$e'.toLowerCase().contains('no result')) await _prefs.setString('geo:$key', '');
      return null;
    }
  }
}

/// Resultado com a distância até o usuário (null quando o endereço não foi localizado).
class NearbyPlace {
  const NearbyPlace(this.place, this.km);
  final RelPlace place;
  final double? km;
}

/// Lista as casas de oração de uma cidade, página por página.
Stream<RelPlace> allPlaces(CcbRelatorio api, String pais, String estado, String cidade, RelFilter filter,
    {int maxPages = 120}) async* {
  for (var p = 1; p <= maxPages; p++) {
    final page = await api.servicos(pais: pais, estado: estado, cidade: cidade, filter: filter, pagina: p);
    for (final x in page.places) {
      yield x;
    }
    if (!page.hasNext || page.places.isEmpty) break;
  }
}
