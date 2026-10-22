import 'dart:math' as math;
import 'dart:typed_data';

import 'package:biblia_hinos_ccb/services/pitch.dart';
import 'package:flutter_test/flutter_test.dart';

Float64List tone(double hz, {int n = 4096, int sr = 44100, bool harmonics = false}) => Float64List.fromList([
      for (var i = 0; i < n; i++)
        0.5 * math.sin(2 * math.pi * hz * i / sr) +
            (harmonics ? 0.3 * math.sin(4 * math.pi * hz * i / sr) + 0.2 * math.sin(6 * math.pi * hz * i / sr) : 0),
    ]);

void main() {
  test('detecta a frequência de notas comuns', () {
    for (final hz in [82.41, 196.0, 440.0, 466.16, 880.0, 1318.5]) {
      final f = detectPitch(tone(hz, harmonics: true), 44100)!;
      expect((f - hz).abs() / hz, lessThan(0.003), reason: '$hz -> $f');
    }
  });

  test('silêncio não dá nota', () {
    expect(detectPitch(Float64List(4096), 44100), isNull);
  });

  test('nome da nota, cents e transposição', () {
    final a = noteFor(440);
    expect((a.name, a.octave, a.cents.round()), ('Lá', 4, 0));
    final sharp = noteFor(445);
    expect((sharp.name, sharp.cents.round()), ('Lá', 20));
    // Si♭ real (466,16 Hz) num clarinete em Si♭ é Dó escrito.
    expect(noteFor(466.16, transpose: 2).name, 'Dó');
    // Dó real (261,63) num sax alto em Mi♭ é Lá escrito.
    expect(noteFor(261.63, transpose: 9).name, 'Lá');
  });

  test('PCM 16 bits vira amostras', () {
    final b = ByteData(4)
      ..setInt16(0, 16384, Endian.little)
      ..setInt16(2, -32768, Endian.little);
    expect(pcm16ToFloat(b.buffer.asUint8List()), [0.5, -1.0]);
  });
}

