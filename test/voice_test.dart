import 'package:biblia_hinos_ccb/screens/voice_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vozes em português: Brasil e alta qualidade primeiro, nomes amigáveis', () {
    final v = portugueseVoices([
      {'name': 'en-us-x-iom-local', 'locale': 'en-US', 'quality': 'very high', 'network_required': '0'},
      {'name': 'pt-pt-x-jfb-local', 'locale': 'pt-PT', 'quality': 'very high', 'network_required': '0'},
      {'name': 'pt-br-x-afs-local', 'locale': 'pt-BR', 'quality': 'normal', 'network_required': '0'},
      {'name': 'pt-br-x-ptd-network', 'locale': 'pt-BR', 'quality': 'very high', 'network_required': '1'},
      {'name': 'pt-BR-SMTf00', 'locale': 'pt-BR', 'quality': 'high', 'network_required': '0'},
      'lixo',
    ]);
    expect(v.map((e) => e.label), ['Voz PTD', 'Feminina 1', 'Voz AFS', 'Voz JFB']);
    expect(v.first.details, 'Brasil · alta qualidade · precisa de internet');
    expect(v[2].details, 'Brasil · funciona sem internet');
    expect(engineLabel('com.samsung.SMT'), 'Samsung');
  });
}
