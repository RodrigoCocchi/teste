import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/click_sound.dart';
import '../services/pitch.dart';
import '../theme.dart';

/// Afinador e metrônomo para os ensaios.
class MusicToolsScreen extends StatelessWidget {
  const MusicToolsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Afinador e metrônomo'),
            bottom: const TabBar(tabs: [
              Tab(icon: Icon(Icons.graphic_eq), text: 'Afinador'),
              Tab(icon: Icon(Icons.av_timer), text: 'Metrônomo'),
            ]),
          ),
          body: const TabBarView(physics: NeverScrollableScrollPhysics(), children: [_Tuner(), _Metronome()]),
        ),
      );
}

// ------------------------------------------------------------------ afinador

class _Tuner extends StatefulWidget {
  const _Tuner();
  @override
  State<_Tuner> createState() => _TunerState();
}

class _TunerState extends State<_Tuner> {
  static const _sr = 44100;
  static const _frame = 4096;
  final _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _buf = <double>[];
  final _recent = <double>[];
  int _sinceLast = 0;
  NoteReading? _note;
  DateTime _lastHeard = DateTime(2000);
  bool _on = false;
  String? _error;
  double _a4 = 440;
  int _transp = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _a4 = p.getDouble('tunerA4') ?? 440;
        _transp = p.getInt('tunerTransp') ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _stop();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      setState(() => _error = 'Permita o uso do microfone para afinar.');
      return;
    }
    final stream = await _rec.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sr, numChannels: 1));
    WakelockPlus.enable();
    _sub = stream.listen(_onData);
    setState(() {
      _on = true;
      _error = null;
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _rec.isRecording()) await _rec.stop();
    WakelockPlus.disable();
    if (mounted) setState(() => _on = false);
  }

  void _onData(Uint8List bytes) {
    _buf.addAll(pcm16ToFloat(bytes));
    _sinceLast += bytes.length ~/ 2;
    if (_buf.length > _frame) _buf.removeRange(0, _buf.length - _frame);
    if (_buf.length < _frame || _sinceLast < 2048) return;
    _sinceLast = 0;
    final hz = detectPitch(Float64List.fromList(_buf), _sr, minHz: 50, maxHz: 1800);
    if (hz == null) {
      if (DateTime.now().difference(_lastHeard).inMilliseconds > 1500 && _note != null) {
        setState(() => _note = null);
      }
      return;
    }
    // Mediana das últimas leituras: ponteiro mais estável.
    _recent.add(hz);
    if (_recent.length > 3) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    _lastHeard = DateTime.now();
    setState(() => _note = noteFor(sorted[sorted.length ~/ 2], a4: _a4, transpose: _transp));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = _note;
    final cents = n?.cents ?? 0;
    final inTune = n != null && cents.abs() <= 5;
    final color = n == null ? t.disabledColor : inTune ? Colors.green : (cents.abs() <= 15 ? Colors.orange : Colors.red);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(
        child: Text(n == null ? '—' : n.name,
            style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: color)),
      ),
      Center(
        child: Text(
          n == null
              ? (_on ? 'Toque uma nota…' : 'Toque em "Começar" para afinar')
              : '${n.letter}${n.octave}  ·  ${n.hz.toStringAsFixed(1).replaceAll('.', ',')} Hz',
          style: t.textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 20),
      _Needle(cents: n == null ? null : cents, color: color),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('♭ baixo'),
        Text(n == null ? '' : inTune ? 'Afinado' : '${cents > 0 ? '+' : ''}${cents.round()} cents',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const Text('alto ♯'),
      ]),
      const SizedBox(height: 20),
      FilledButton.icon(
        icon: Icon(_on ? Icons.stop : Icons.mic),
        label: Text(_on ? 'Parar' : 'Começar'),
        onPressed: _on ? _stop : _start,
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: t.colorScheme.error))),
      const SizedBox(height: 20),
      DropdownButtonFormField<int>(
        initialValue: _transp,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Instrumento (afinação)', border: OutlineInputBorder()),
        items: [
          for (final tr in transpositions)
            DropdownMenuItem(value: tr.semitones, child: Text('${tr.name} — ${tr.examples}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          setState(() => _transp = v ?? 0);
          SharedPreferences.getInstance().then((p) => p.setInt('tunerTransp', _transp));
        },
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Text('Lá de referência:'),
        IconButton(
            onPressed: () => _setA4(_a4 - 1), icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir'),
        Text('${_a4.round()} Hz', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(onPressed: () => _setA4(_a4 + 1), icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar'),
      ]),
      Text('Com instrumento transpositor, o afinador mostra a nota escrita na partitura.',
          style: t.textTheme.bodySmall),
    ]);
  }

  void _setA4(double v) {
    setState(() => _a4 = v.clamp(430, 450));
    SharedPreferences.getInstance().then((p) => p.setDouble('tunerA4', _a4));
  }
}

class _Needle extends StatelessWidget {
  const _Needle({required this.cents, required this.color});
  final double? cents;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final x = cents == null ? w / 2 : w / 2 + (cents!.clamp(-50, 50) / 50) * (w / 2 - 6);
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 26,
              child: Container(height: 4, color: Theme.of(context).dividerColor),
            ),
            Positioned(
              left: w / 2 - w * 0.05,
              width: w * 0.1,
              top: 20,
              child: Container(height: 16, color: Colors.green.withValues(alpha: 0.25)),
            ),
            for (final f in [-50, -25, 0, 25, 50])
              Positioned(left: w / 2 + f / 50 * (w / 2 - 6) - 1, top: 18, child: Container(width: 2, height: 20, color: Colors.grey)),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              left: x - 4,
              top: 0,
              child: Container(width: 8, height: 56, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ metrônomo

class _Metronome extends StatefulWidget {
  const _Metronome();
  @override
  State<_Metronome> createState() => _MetronomeState();
}

class _MetronomeState extends State<_Metronome> {
  final _accent = AudioPlayer();
  final _beat = AudioPlayer();
  String? _accentPath, _beatPath;
  int _bpm = 80;
  int _beats = 4; // 1 = sem acento
  bool _on = false;
  int _current = -1;
  Timer? _timer;
  final _clock = Stopwatch();
  int _tick = 0;
  final _taps = <DateTime>[];

  @override
  void initState() {
    super.initState();
    _prepare();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _bpm = p.getInt('metroBpm') ?? 80;
        _beats = p.getInt('metroBeats') ?? 4;
      });
    });
  }

  Future<void> _prepare() async {
    final dir = (await getTemporaryDirectory()).path;
    final a = File(p.join(dir, 'click_accent.wav'))..writeAsBytesSync(clickWav(hz: 1600));
    final b = File(p.join(dir, 'click_beat.wav'))..writeAsBytesSync(clickWav(hz: 1000));
    _accentPath = a.path;
    _beatPath = b.path;
    for (final pl in [_accent, _beat]) {
      await pl.setPlayerMode(PlayerMode.lowLatency);
      await pl.setReleaseMode(ReleaseMode.stop);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    _accent.dispose();
    _beat.dispose();
    super.dispose();
  }

  void _save() => SharedPreferences.getInstance().then((p) {
        p.setInt('metroBpm', _bpm);
        p.setInt('metroBeats', _beats);
      });

  void _toggle() {
    if (_on) {
      _timer?.cancel();
      _clock.stop();
      WakelockPlus.disable();
      setState(() {
        _on = false;
        _current = -1;
      });
      return;
    }
    if (_accentPath == null) return;
    WakelockPlus.enable();
    _tick = 0;
    _clock
      ..reset()
      ..start();
    setState(() => _on = true);
    _schedule();
  }

  /// Agenda pelo relógio desde o início, para não acumular atraso.
  void _schedule() {
    final interval = 60000 / _bpm;
    final due = (_tick * interval).round();
    final wait = due - _clock.elapsedMilliseconds;
    _timer = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () {
      if (!_on) return;
      final beat = _beats <= 1 ? 0 : _tick % _beats;
      final accent = _beats > 1 && beat == 0;
      (accent ? _accent : _beat).play(DeviceFileSource(accent ? _accentPath! : _beatPath!));
      setState(() => _current = beat);
      _tick++;
      _schedule();
    });
  }

  void _setBpm(int v) {
    final wasOn = _on;
    if (wasOn) _toggle();
    setState(() => _bpm = v.clamp(30, 240));
    _save();
    if (wasOn) _toggle();
  }

  void _tap() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inSeconds > 2) _taps.clear();
    _taps.add(now);
    final bpm = tapTempo(_taps);
    if (bpm != null) _setBpm(bpm);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: Text('$_bpm', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.navy))),
      const Center(child: Text('batidas por minuto')),
      const SizedBox(height: 12),
      Row(children: [
        IconButton.outlined(onPressed: () => _setBpm(_bpm - 1), icon: const Icon(Icons.remove), tooltip: 'Mais lento'),
        Expanded(
          child: Slider(
            min: 30,
            max: 240,
            value: _bpm.toDouble(),
            onChanged: (v) => setState(() => _bpm = v.round()),
            onChangeEnd: (v) => _setBpm(v.round()),
          ),
        ),
        IconButton.outlined(onPressed: () => _setBpm(_bpm + 1), icon: const Icon(Icons.add), tooltip: 'Mais rápido'),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < (_beats <= 1 ? 1 : _beats); i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: i == 0 && _beats > 1 ? 30 : 24,
            height: i == 0 && _beats > 1 ? 30 : 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _current == i ? (i == 0 && _beats > 1 ? AppColors.gold : AppColors.navy) : t.dividerColor,
            ),
          ),
      ]),
      const SizedBox(height: 20),
      FilledButton.icon(
        icon: Icon(_on ? Icons.stop : Icons.play_arrow),
        label: Text(_on ? 'Parar' : 'Começar'),
        onPressed: _toggle,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(Icons.touch_app), label: const Text('Toque no ritmo (tap)'), onPressed: _tap),
      const SizedBox(height: 20),
      const Text('Compasso'),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 1, label: Text('Sem')),
          ButtonSegment(value: 2, label: Text('2/4')),
          ButtonSegment(value: 3, label: Text('3/4')),
          ButtonSegment(value: 4, label: Text('4/4')),
          ButtonSegment(value: 6, label: Text('6/8')),
        ],
        selected: {_beats},
        onSelectionChanged: (v) {
          setState(() => _beats = v.first);
          _save();
        },
      ),
    ]);
  }
}
