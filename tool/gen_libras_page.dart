// Gera a página do tradutor de Libras para o teste no navegador (CI).
import 'dart:io';

import 'package:biblia_hinos_ccb/data/libras_page.dart';

void main(List<String> args) => File(args.first).writeAsStringSync(librasHtml);
