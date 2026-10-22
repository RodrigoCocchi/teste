import 'dart:math' as math;
import 'dart:typed_data';

/// Gera um "clique" curto em WAV (PCM 16 bits mono) para o metrônomo.
Uint8List clickWav({double hz = 1000, int ms = 35, int sampleRate = 44100, double volume = 0.9}) {
  final n = sampleRate * ms ~/ 1000;
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final env = math.exp(-6.0 * i / n); // decaimento rápido
    final v = volume * env * math.sin(2 * math.pi * hz * i / sampleRate);
    data.setInt16(44 + i * 2, (v * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Andamento a partir dos toques (média dos intervalos recentes), em BPM.
int? tapTempo(List<DateTime> taps) {
  if (taps.length < 2) return null;
  final recent = taps.length > 6 ? taps.sublist(taps.length - 6) : taps;
  var total = 0;
  for (var i = 1; i < recent.length; i++) {
    total += recent[i].difference(recent[i - 1]).inMilliseconds;
  }
  final avg = total / (recent.length - 1);
  if (avg <= 0) return null;
  return (60000 / avg).round().clamp(30, 240);
}
