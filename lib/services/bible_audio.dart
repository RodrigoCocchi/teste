import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Motor de voz (separado para os testes não dependerem do Android).
abstract class SpeechEngine {
  Future<bool> init();
  Future<void> setRate(double rate);

  /// Fala o texto e só termina quando a fala acaba (ou é interrompida).
  Future<void> speak(String text);
  Future<void> stop();
}

/// Voz do próprio aparelho (leitura em voz alta do Android), em português.
class DeviceSpeech implements SpeechEngine {
  final _tts = FlutterTts();

  @override
  Future<bool> init() async {
    await _tts.awaitSpeakCompletion(true);
    final ok = await _tts.isLanguageAvailable('pt-BR');
    await _tts.setLanguage(ok == true ? 'pt-BR' : 'pt-PT');
    return ok == true || await _tts.isLanguageAvailable('pt-PT') == true;
  }

  @override
  Future<void> setRate(double rate) async => _tts.setSpeechRate(rate);

  @override
  Future<void> speak(String text) async => _tts.speak(text);

  @override
  Future<void> stop() async => _tts.stop();
}

/// Velocidades oferecidas (rótulo → taxa do motor; 0,5 é a fala normal no Android).
const Map<String, double> audioSpeeds = {'0,75x': 0.38, '1x': 0.5, '1,25x': 0.62, '1,5x': 0.75};

enum AudioState { idle, playing, paused }

/// Lê um capítulo versículo por versículo, avisando qual está sendo lido.
class ChapterAudio extends ChangeNotifier {
  ChapterAudio(this._engine);
  final SpeechEngine _engine;

  AudioState state = AudioState.idle;
  int? current; // número do versículo em leitura (ou onde pausou)
  String speed = '1x';
  bool? voiceAvailable;

  String _title = '';
  List<(int, String)> _verses = const [];
  int _run = 0; // cada play/stop invalida a leitura anterior

  /// Chamado quando o capítulo termina de ser lido (para seguir ao próximo).
  VoidCallback? onChapterEnd;

  Future<bool> _ensureInit() async {
    voiceAvailable ??= await _engine.init();
    await _engine.setRate(audioSpeeds[speed]!);
    return voiceAvailable!;
  }

  /// Começa a ler [verses] (número, texto) a partir de [from], anunciando [title].
  Future<void> play(String title, List<(int, String)> verses, {int? from}) async {
    final run = ++_run;
    await _engine.stop();
    if (!await _ensureInit() || run != _run) return;
    _title = title;
    _verses = verses;
    state = AudioState.playing;
    final start = from ?? (verses.isEmpty ? null : verses.first.$1);
    final announce = from == null || from == verses.firstOrNull?.$1;
    notifyListeners();
    if (announce) {
      await _engine.speak('$title.');
      if (run != _run) return;
    }
    for (final (n, text) in verses) {
      if (start != null && n < start) continue;
      current = n;
      notifyListeners();
      await _engine.speak(text);
      if (run != _run) return;
    }
    state = AudioState.idle;
    current = null;
    notifyListeners();
    onChapterEnd?.call();
  }

  /// Pausa guardando o versículo atual; [resume] continua dele.
  Future<void> pause() async {
    if (state != AudioState.playing) return;
    _run++;
    state = AudioState.paused;
    notifyListeners();
    await _engine.stop();
  }

  Future<void> resume() async {
    if (state != AudioState.paused) return;
    await play(_title, _verses, from: current);
  }

  Future<void> stop() async {
    _run++;
    state = AudioState.idle;
    current = null;
    notifyListeners();
    await _engine.stop();
  }

  /// Troca a velocidade; se estiver lendo, recomeça o versículo atual na nova velocidade.
  Future<void> setSpeed(String label) async {
    speed = label;
    notifyListeners();
    if (state == AudioState.playing) {
      final from = current;
      await play(_title, _verses, from: from);
    }
  }

  @override
  void dispose() {
    _run++;
    _engine.stop();
    super.dispose();
  }
}
