import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/setup_service.dart';
import '../theme.dart';

/// Tela de preparação automática: mostra o que o app está fazendo.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = App.I.setup;
    return ListenableBuilder(
      listenable: setup,
      builder: (context, _) {
        final t = Theme.of(context);
        final done = !setup.running && setup.finished;
        return Scaffold(
          backgroundColor: AppColors.navy,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 12),
              Center(child: Image.asset('assets/images/icon.png', width: 120)),
              const SizedBox(height: 20),
              Text(done ? 'Tudo pronto!' : 'Preparando o aplicativo',
                  textAlign: TextAlign.center,
                  style: t.textTheme.headlineSmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                done
                    ? 'A Bíblia e o Hinário já estão no celular e funcionam sem internet.'
                    : 'Estamos baixando a Bíblia e o Hinário 5 e organizando tudo. '
                        'Isso acontece só uma vez e pode levar alguns minutos. '
                        'Use, de preferência, uma rede Wi-Fi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              for (final s in setup.steps) _StepTile(step: s),
              const SizedBox(height: 24),
              if (setup.running)
                Text(setup.headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gold, fontSize: 13)),
              if (!setup.running && !done) ...[
                Text(setup.headline,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  onPressed: setup.run,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: done ? AppColors.gold : Colors.white24,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(done ? 'Começar' : 'Usar o app enquanto isso'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});
  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (step.state) {
      SetupState.done => (Icons.check_circle, Colors.greenAccent),
      SetupState.failed => (Icons.error_outline, Colors.orangeAccent),
      SetupState.running => (Icons.downloading, AppColors.gold),
      SetupState.pending => (Icons.radio_button_unchecked, Colors.white38),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(step.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (step.state == SetupState.running) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: step.progress,
                color: AppColors.gold,
                backgroundColor: Colors.white12,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Faixa compacta com o andamento, para a tela inicial.
class SetupBanner extends StatelessWidget {
  const SetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = App.I.setup;
    return ListenableBuilder(
      listenable: setup,
      builder: (context, _) {
        if (!setup.running && !setup.needed) return const SizedBox.shrink();
        final current = setup.steps.where((s) => s.state == SetupState.running).firstOrNull;
        return Card(
          margin: const EdgeInsets.only(top: 12),
          color: AppColors.gold.withValues(alpha: 0.15),
          child: ListTile(
            leading: setup.running
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.download),
            title: Text(setup.running ? 'Preparando o aplicativo…' : 'Preparação incompleta'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(setup.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (current != null) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: current.progress),
              ],
            ]),
            onTap: () {
              if (!setup.running) setup.run();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
            },
          ),
        );
      },
    );
  }
}
