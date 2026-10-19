// Gera a página do tradutor de Libras para o teste no navegador (CI).
import 'dart:io';

import 'package:biblia_hinos_ccb/data/libras_phrases.dart';
import 'package:biblia_hinos_ccb/screens/libras_screen.dart';

void main(List<String> args) => File(args.first).writeAsStringSync(librasHtml(librasPhrases));
