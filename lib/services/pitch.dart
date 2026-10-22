import 'dart:math' as math;
import 'dart:typed_data';

/// Detecção de altura (frequência fundamental) pelo método YIN.
/// Devolve a frequência em Hz, ou null quando há silêncio/ruído.
double? detectPitch(Float64List x, int sampleRate,
    {double minHz = 40, double maxHz = 2000, double threshold = 0.15, double minRms = 0.01}) {
  final n = x.length;
  var sum = 0.0;
  for (final v in x) {
    sum += v * v;
  }
  if (math.sqrt(sum / n) < minRms) return null;

  final maxTau = math.min(n ~/ 2, sampleRate ~/ minHz);
  final minTau = math.max(2, sampleRate ~/ maxHz);
  final w = n - maxTau;
  final d = Float64List(maxTau + 1);
  for (var tau = 1; tau <= maxTau; tau++) {
    var s = 0.0;
    for (var i = 0; i < w; i++) {
      final diff = x[i] - x[i + tau];
      s += diff * diff;
    }
    d[tau] = s;
  }
  // Diferença normalizada cumulativa.
  final cmnd = Float64List(maxTau + 1)..[0] = 1;
  var running = 0.0;
  for (var tau = 1; tau <= maxTau; tau++) {
    running += d[tau];
    cmnd[tau] = running == 0 ? 1 : d[tau] * tau / running;
  }
  var tau = -1;
  for (var t = minTau; t <= maxTau; t++) {
    if (cmnd[t] < threshold) {
      while (t + 1 <= maxTau && cmnd[t + 1] < cmnd[t]) {
        t++;
      }
      tau = t;
      break;
    }
  }
  if (tau < 0) return null;
  // Interpolação parabólica para precisão abaixo de 1 amostra.
  var better = tau.toDouble();
  if (tau > 1 && tau < maxTau) {
    final s0 = cmnd[tau - 1], s1 = cmnd[tau], s2 = cmnd[tau + 1];
    final den = 2 * (2 * s1 - s2 - s0);
    if (den != 0) better = tau + (s2 - s0) / den;
  }
  return sampleRate / better;
}

/// Converte PCM 16 bits little-endian (mono) em amostras de -1 a 1.
Float64List pcm16ToFloat(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final out = Float64List(bytes.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

const List<String> noteNames = ['Dó', 'Dó♯', 'Ré', 'Mi♭', 'Mi', 'Fá', 'Fá♯', 'Sol', 'Lá♭', 'Lá', 'Si♭', 'Si'];
const List<String> noteLetters = ['C', 'C♯', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B'];

/// Instrumento transpositor: [semitones] somados à nota real para obter a nota escrita.
class Transposition {
  const Transposition(this.name, this.semitones, this.examples);
  final String name;
  final int semitones;
  final String examples;
}

const List<Transposition> transpositions = [
  Transposition('Dó (som real)', 0, 'violino, viola, violoncelo, flauta, oboé, fagote, órgão, trombone'),
  Transposition('Si♭', 2, 'clarinete, trompete, sax soprano e tenor'),
  Transposition('Mi♭', 9, 'sax alto e barítono'),
  Transposition('Fá', 7, 'trompa, corne inglês'),
];

/// Nota mais próxima: nome, oitava e desvio em cents (-50 a +50).
class NoteReading {
  const NoteReading(this.index, this.octave, this.cents, this.hz);
  final int index; // 0 = Dó
  final int octave;
  final double cents;
  final double hz;
  String get name => noteNames[index];
  String get letter => noteLetters[index];
}

NoteReading noteFor(double hz, {double a4 = 440, int transpose = 0}) {
  final midi = 69 + 12 * math.log(hz / a4) / math.ln2;
  final nearest = midi.round();
  final written = nearest + transpose;
  return NoteReading(written % 12, written ~/ 12 - 1, (midi - nearest) * 100, hz);
}
