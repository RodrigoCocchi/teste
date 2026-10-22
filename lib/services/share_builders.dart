import 'package:flutter/material.dart';

import '../data/agenda_repository.dart';
import '../data/organ_repository.dart';
import '../data/places_repository.dart';
import 'profile.dart';
import '../widgets/share_card.dart';

const String shareFooter = 'Enviado pelo app Bíblia & Hinos';

/// Cartão de um culto de uma casa de oração.
ShareCardData cultoShare(SavedPlace p, CultoTime c, DateTime at) => ShareCardData(
      kicker: c.kind,
      title: p.place.name,
      subtitle: '${longDate(at)} · ${c.time}',
      icon: Icons.event,
      sections: [
        ShareSection(rows: [
          if (p.place.address.isNotEmpty) ('Endereço', p.place.address),
          if (p.place.city.isNotEmpty) ('Cidade', p.place.city),
        ]),
      ],
      footer: shareFooter,
    );

/// Cartão de um compromisso da agenda (ensaio, Santa Ceia, batismo…).
ShareCardData eventShare(AgendaEvent e, DateTime at) => ShareCardData(
      kicker: e.kind,
      title: e.displayTitle == e.kind && e.place.isNotEmpty ? e.place : e.displayTitle,
      subtitle: '${longDate(at)} · ${hhmm(at)}',
      icon: agendaIcon(e.kind),
      sections: [
        ShareSection(rows: [
          if (e.place.isNotEmpty && e.displayTitle != e.kind) ('Local', e.place),
          if (e.repeat != 'none') ('Repete', repeatOptions[e.repeat] ?? ''),
          if (e.notes.isNotEmpty) (e.notes, ''),
        ]),
      ],
      footer: shareFooter,
    );

String dutyLine(OrganDuty d) =>
    d.startsHalfHourBefore ? '${d.part} · ${hhmm(d.playAt)} (culto ${hhmm(d.at)})' : '${d.part} · ${hhmm(d.at)}';

/// Cartão de um compromisso da organista.
ShareCardData dutyShare(OrganDuty d, String organist) => ShareCardData(
      kicker: 'Escala do órgão',
      title: organist.isEmpty ? 'Organista' : organist,
      subtitle: longDate(d.at),
      icon: Icons.piano,
      sections: [
        ShareSection(rows: [
          (dutyLine(d), ''),
          if (d.place.isNotEmpty) ('Local', d.place),
          if (d.notes.isNotEmpty) (d.notes, ''),
        ]),
      ],
      footer: shareFooter,
    );

/// Escala do mês inteira, agrupada por dia.
ShareCardData monthScaleShare(List<OrganDuty> duties, Map<int, String> names, int year, int month, String place) {
  final byDay = <DateTime, List<OrganDuty>>{};
  for (final d in duties) {
    byDay.putIfAbsent(DateTime(d.at.year, d.at.month, d.at.day), () => []).add(d);
  }
  return ShareCardData(
    kicker: 'Escala de organistas',
    title: place.isEmpty ? '${monthNames[month - 1]} de $year' : place,
    subtitle: place.isEmpty ? null : '${monthNames[month - 1][0].toUpperCase()}${monthNames[month - 1].substring(1)} de $year',
    icon: Icons.piano,
    sections: [
      for (final e in byDay.entries)
        ShareSection(
          title: '${two(e.key.day)}/${two(e.key.month)} · ${weekdayLong[e.key.weekday - 1]}',
          rows: [
            for (final d in e.value)
              (dutyLine(d), d.organistId == null ? '—' : names[d.organistId] ?? '—'),
          ],
        ),
    ],
    footer: shareFooter,
  );
}

/// Cartão do aniversário de batismo.
ShareCardData baptismShare(Profile p, int years) => ShareCardData(
      kicker: 'Aniversário de batismo',
      title: p.name.isEmpty ? '$years ${years == 1 ? 'ano' : 'anos'} de batismo' : p.name,
      subtitle: p.name.isEmpty ? null : '$years ${years == 1 ? 'ano' : 'anos'} de batismo',
      icon: Icons.water_drop_outlined,
      sections: [
        ShareSection(rows: [
          if (p.baptismDate != null) ('Batismo', '${two(p.baptismDate!.day)}/${two(p.baptismDate!.month)}/${p.baptismDate!.year}'),
          if (p.baptismChurch.isNotEmpty) ('Igreja', p.baptismChurch),
          if (p.baptismMinister.isNotEmpty) ('Ministério', p.baptismMinister),
          ('Deus seja louvado!', ''),
        ]),
      ],
      footer: shareFooter,
    );
