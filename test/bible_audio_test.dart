import 'dart:async';

import 'package:biblia_hinos_ccb/services/bible_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motor falso: registra as falas; cada fala termina quando o teste manda.
class FakeSpeech implements SpeechEngine {
  final spoken = <String>[];
  Completer<void>? _cur;
  bool available = true;

  @override
  Future<bool> init() async => available;
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _cur = Completer<void>();
    return _cur!.future;
  }

  @override
  Future<void> stop() async {
    final c = _cur;
    _cur = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> finish() async {
    final c = _cur;
    _cur = null;
    c?.complete();
    await Future<void>.delayed(Duration.zero);
  }
}

const verses = [(1, 'No princípio'), (2, 'E a terra'), (3, 'E disse Deus')];

void main() {
  test('lê o título e os versículos em ordem e avisa o fim do capítulo', () async {
    final e = FakeSpeech();
    final a = ChapterAudio(e);
    var ended = false;
    a.onChapterEnd = () => ended = true;
    final done = a.play('Gênesis, capítulo 1', verses);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 4; i++) {
      await e.finish();
    }
    await done;
    expect(e.spoken, ['Gênesis, capítulo 1.', 'No princípio', 'E a terra', 'E disse Deus']);
    expect(ended, isTrue);
    expect(a.state, AudioState.idle);
  });

  test('pausa e continua do mesmo versículo', () async {
    final e = FakeSpeech();
    final a = ChapterAudio(e);
    unawaited(a.play('Gn 1', verses, from: 2));
    await Future<void>.delayed(Duration.zero);
    expect(e.spoken, ['E a terra']);
    expect(a.current, 2);
    await a.pause();
    expect(a.state, AudioState.paused);
    unawaited(a.resume());
    await Future<void>.delayed(Duration.zero);
    expect(e.spoken.last, 'E a terra');
    await e.finish();
    expect(e.spoken.last, 'E disse Deus');
    await a.stop();
    expect(a.state, AudioState.idle);
  });

  test('sem voz em português não começa', () async {
    final e = FakeSpeech()..available = false;
    final a = ChapterAudio(e);
    await a.play('Gn 1', verses);
    expect(e.spoken, isEmpty);
    expect(a.voiceAvailable, isFalse);
    expect(a.state, AudioState.idle);
  });
}
