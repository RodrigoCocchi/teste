import 'package:biblia_hinos_ccb/services/click_sound.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clique WAV válido', () {
    final w = clickWav(ms: 30);
    expect(String.fromCharCodes(w.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(w.sublist(8, 12)), 'WAVE');
    expect(w.length, 44 + 44100 * 30 ~/ 1000 * 2);
  });

  test('andamento pelos toques', () {
    final t0 = DateTime(2026);
    final taps = [for (var i = 0; i < 5; i++) t0.add(Duration(milliseconds: 500 * i))];
    expect(tapTempo(taps), 120);
    expect(tapTempo(taps.take(1).toList()), isNull);
  });
}
