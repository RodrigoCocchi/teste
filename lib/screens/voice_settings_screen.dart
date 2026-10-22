import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bible_audio.dart';
import '../widgets/common.dart';

/// Voz disponível no aparelho.
class TtsVoice {
  const TtsVoice(this.name, this.locale, this.quality, this.network);
  final String name;
  final String locale;
  final String quality; // very high | high | normal | low | very low | unknown
  final bool network;

  static TtsVoice? fromMap(Object? m) {
    if (m is! Map) return null;
    final name = m['name']?.toString(), locale = m['locale']?.toString();
    if (name == null || locale == null) return null;
    return TtsVoice(name, locale, m['quality']?.toString() ?? 'unknown', m['network_required']?.toString() == '1');
  }

  int get _rank => const {'very high': 5, 'high': 4, 'normal': 3, 'low': 2, 'very low': 1}[quality] ?? 0;

  /// Nome amigável: "Voz AFS", "Feminina 1" (Samsung)…
  String get label {
    final samsung = RegExp(r'SMT([fm])(\d+)', caseSensitive: false).firstMatch(name);
    if (samsung != null) {
      final n = int.parse(samsung[2]!) + 1;
      return '${samsung[1]!.toLowerCase() == 'f' ? 'Feminina' : 'Masculina'} $n';
    }
    final google = RegExp(r'-x-([a-z]{3})', caseSensitive: false).firstMatch(name);
    if (google != null) return 'Voz ${google[1]!.toUpperCase()}';
    if (name.toLowerCase().endsWith('language')) return 'Voz padrão';
    return name;
  }

  String get details => [
        locale.toLowerCase() == 'pt-br' ? 'Brasil' : 'Portugal',
        if (_rank >= 4) 'alta qualidade',
        network ? 'precisa de internet' : 'funciona sem internet',
      ].join(' · ');
}

/// Ordena as vozes em português: Brasil primeiro, depois maior qualidade.
List<TtsVoice> portugueseVoices(Iterable<Object?> raw) {
  final list = [
    for (final m in raw)
      if (TtsVoice.fromMap(m) case final v? when v.locale.toLowerCase().startsWith('pt')) v,
  ];
  list.sort((a, b) {
    final br = (b.locale.toLowerCase() == 'pt-br' ? 1 : 0) - (a.locale.toLowerCase() == 'pt-br' ? 1 : 0);
    if (br != 0) return br;
    final q = b._rank - a._rank;
    if (q != 0) return q;
    return a.label.compareTo(b.label);
  });
  return list;
}

String engineLabel(String pkg) => switch (pkg) {
      'com.google.android.tts' => 'Google',
      'com.samsung.SMT' => 'Samsung',
      _ => pkg.split('.').last,
    };

const String voiceSample = 'No princípio, criou Deus os céus e a terra.';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});
  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final _tts = FlutterTts();
  SharedPreferences? _prefs;
  List<String> _engines = [];
  String? _engine;
  List<TtsVoice> _voices = [];
  String? _voice; // nome
  double _pitch = 1.0;
  String _speed = '1x';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    final p = _prefs = await SharedPreferences.getInstance();
    _pitch = p.getDouble(VoicePrefs.pitchKey) ?? 1.0;
    _speed = p.getString('audioSpeed') ?? '1x';
    _voice = p.getString(VoicePrefs.voiceNameKey);
    try {
      _engines = [for (final e in (await _tts.getEngines) as List? ?? const []) '$e'];
      _engine = p.getString(VoicePrefs.engineKey) ?? (await _tts.getDefaultEngine)?.toString();
    } on Object {
      _engines = [];
    }
    await _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() => _loading = true);
    try {
      await VoicePrefs.apply(_tts, _prefs!);
      _voices = portugueseVoices((await _tts.getVoices) as List? ?? const []);
    } on Object {
      _voices = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _preview([TtsVoice? v]) async {
    await _tts.stop();
    if (v != null) await _tts.setVoice({'name': v.name, 'locale': v.locale});
    await _tts.setPitch(_pitch);
    await _tts.setSpeechRate(audioSpeeds[_speed] ?? 0.5);
    await _tts.speak(voiceSample);
  }

  Future<void> _chooseEngine(String e) async {
    final p = _prefs!;
    await p.setString(VoicePrefs.engineKey, e);
    await p.remove(VoicePrefs.voiceNameKey);
    await p.remove(VoicePrefs.voiceLocaleKey);
    setState(() {
      _engine = e;
      _voice = null;
    });
    await _loadVoices();
  }

  Future<void> _chooseVoice(TtsVoice v) async {
    await _prefs!.setString(VoicePrefs.voiceNameKey, v.name);
    await _prefs!.setString(VoicePrefs.voiceLocaleKey, v.locale);
    setState(() => _voice = v.name);
    await _preview(v);
  }

  Future<void> _openSystemTts() async {
    try {
      await const AndroidIntent(action: 'com.android.settings.TTS_SETTINGS').launch();
    } on Object {
      if (mounted) showSnack(context, 'Abra Configurações > Gerenciamento geral > Conversão de texto em voz.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Voz do leitor')),
      body: ListView(children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_engines.length > 1) ...[
          const SectionTitle('Motor de voz'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, children: [
              for (final e in _engines)
                ChoiceChip(label: Text(engineLabel(e)), selected: e == _engine, onSelected: (_) => _chooseEngine(e)),
            ]),
          ),
        ],
        const SectionTitle('Tom e velocidade'),
        ListTile(
          title: Text('Tom: ${_pitch.toStringAsFixed(1).replaceAll('.', ',')}'),
          subtitle: Slider(
            min: 0.7,
            max: 1.4,
            divisions: 7,
            value: _pitch.clamp(0.7, 1.4),
            onChanged: (v) => setState(() => _pitch = v),
            onChangeEnd: (v) {
              _prefs?.setDouble(VoicePrefs.pitchKey, v);
              _preview();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [for (final s in audioSpeeds.keys) ButtonSegment(value: s, label: Text(s))],
            selected: {_speed},
            onSelectionChanged: (s) {
              setState(() => _speed = s.first);
              _prefs?.setString('audioSpeed', s.first);
              _preview();
            },
          ),
        ),
        const SectionTitle('Vozes em português'),
        if (!_loading && _voices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nenhuma voz em português encontrada neste motor. Instale a voz pelo botão abaixo.'),
          ),
        RadioGroup<String>(
          groupValue: _voice,
          onChanged: (name) {
            final v = _voices.where((x) => x.name == name).firstOrNull;
            if (v != null) _chooseVoice(v);
          },
          child: Column(children: [
            for (final v in _voices)
              RadioListTile<String>(
                value: v.name,
                title: Text(v.label),
                subtitle: Text(v.details),
                secondary: IconButton(
                    tooltip: 'Ouvir', icon: const Icon(Icons.play_circle_outline), onPressed: () => _preview(v)),
              ),
          ]),
        ),
        const SectionTitle('Vozes mais naturais'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'As vozes marcadas "alta qualidade" e as que "precisam de internet" costumam soar menos robóticas. '
            'Para ter mais opções, instale ou atualize os "Serviços de voz do Google" e baixe a voz '
            'Português (Brasil) nas configurações de voz do celular.',
            style: t.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.shop_outlined),
              label: const Text('Serviços de voz do Google'),
              onPressed: () => launchUrl(Uri.parse('market://details?id=com.google.android.tts'),
                  mode: LaunchMode.externalApplication),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings_voice_outlined),
              label: const Text('Configurações de voz do celular'),
              onPressed: _openSystemTts,
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar lista'),
              onPressed: _loadVoices,
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
