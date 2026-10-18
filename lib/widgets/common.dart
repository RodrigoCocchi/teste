import 'package:flutter/material.dart';

import '../core/bible_ref.dart';
import '../data/bible_repository.dart';
import '../screens/nav.dart';
import '../services/app_services.dart';
import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(title, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2, color: AppColors.gold, fontWeight: FontWeight.w700)),
      );
}

/// Rótulo que separa texto bíblico de texto autoral.
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.biblical});
  final bool biblical;
  @override
  Widget build(BuildContext context) {
    final color = biblical ? AppColors.navyLight : AppColors.gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(biblical ? 'TEXTO BÍBLICO' : 'TEXTO AUTORAL (NÃO OFICIAL)',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Mostra o texto de uma referência lido do banco (nunca de conteúdo fixo).
class PassageView extends StatelessWidget {
  const PassageView(this.ref, {super.key, this.compact = false});
  final BibleRef ref;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return FutureBuilder<List<Verse>>(
      future: App.I.bible.range(ref),
      builder: (context, snap) {
        final verses = snap.data;
        Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = const LinearProgressIndicator();
        } else if (verses == null || verses.isEmpty) {
          body = Text(
              'Texto não disponível: importe e indexe a Bíblia (Configurações › Documentos) '
              'ou abra a passagem no PDF.',
              style: t.textTheme.bodySmall);
        } else {
          body = Text.rich(TextSpan(children: [
            for (final v in verses) ...[
              TextSpan(
                  text: '${v.verse} ',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold)),
              TextSpan(text: '${v.text} '),
            ],
          ]), style: t.textTheme.bodyLarge?.copyWith(height: 1.5));
        }
        return InkWell(
          onTap: () => openRef(context, ref),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ref.label,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              body,
            ]),
          ),
        );
      },
    );
  }
}

void showSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
