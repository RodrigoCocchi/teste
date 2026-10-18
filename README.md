# Bíblia & Hinos CCB

Aplicativo Android pessoal, em Flutter e 100% offline. Reúne a Bíblia (ARC 1969), o Hinário 5, uma pesquisa universal, um quiz bíblico, o Estudo do Dia e um plano de leitura anual.

> Os PDFs **não** acompanham o código nem o APK. Importe-os no celular em
> *Configurações › Documentos*.

## Compilar

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
```

O APK release usa a assinatura de debug do template (instalação manual, sem Play Store).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `lib/core` | normalização de texto (sem acentos) e parser de referências ("Jo 3:16") |
| `lib/data` | SQLite (`database.dart`), repositórios, 66 livros, plano anual |
| `lib/services` | extração do PDF em isolate (`pdf_text_service.dart`), estruturação livro/capítulo/versículo (`bible_parser.dart`), documentos, preferências |
| `lib/screens` | telas (Início, Bíblia, Leitor, PDF, Hinário, Quiz, Favoritos, Estudo, Plano, Temas, Documentos) |
| `assets/data` | `quiz.json` (120 perguntas), `themes.json` (21 temas), `studies.json` (38 estudos) |
| `tool/` | `verify_quiz.dart` (confere o quiz) e `extract_bible_test.dart` (extrai a Bíblia do PDF no PC) |
| `test/` | testes de conteúdo, parser, pipeline PDF real, banco de dados e widgets |

**Tabelas SQLite:** `bible_book`, `bible_chapter`, `bible_verse`, `verse_fts` (índice FTS5/FTS4 sem cópia do texto), `bible_theme`, `theme_reference`, `hymn`, `hymn_page`, `favorite`, `bookmark` (marcações e notas), `reading_history`, `bible_question`, `quiz_session`, `quiz_answer`, `daily_study`, `reading_plan`, `reading_progress`.

## Scripts

```bash
dart run tool/verify_quiz.dart                         # estrutura das perguntas
dart run tool/verify_quiz.dart biblia_estruturada.json # + conferência no texto bíblico
BIBLE_PDF=/caminho/biblia.pdf flutter test tool/extract_bible_test.dart
```

## Como os textos são tratados

- **Texto bíblico:** vem somente do documento importado. Se a extração falha, o capítulo fica ausente (nada é inventado), e o leitor oferece o PDF. Capítulos com sinais de erro aparecem com aviso "conferir no PDF".
- **Quiz:** cada pergunta tem referências e palavras-chave. Ela só aparece como *conferida* depois que as palavras-chave são encontradas no texto bíblico importado. O JSON nunca se declara conferido.
- **Estudos e reflexões:** são textos autorais, marcados assim na tela, e não são ensinamentos oficiais da CCB. O texto bíblico dos estudos é lido da Bíblia importada.
- **Hinário:** não traz títulos, letras nem páginas inventados. A página de cada hino vem de um mapeamento persistente: linear, por detecção automática quando o PDF tem texto, ou manual pelo menu do hino.
