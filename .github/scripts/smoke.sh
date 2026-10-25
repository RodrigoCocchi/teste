#!/usr/bin/env bash
# Instala o APK no emulador, abre o app e acompanha a preparação automática.
set -u
APK=build/app/outputs/flutter-apk/app-release.apk
PKG=br.pessoal.biblia_hinos_ccb
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
mkdir -p smoke
textos() {
  # O dump falha se a interface estiver ocupada: tenta algumas vezes.
  for _ in 1 2 3 4 5; do
    adb shell rm -f /sdcard/ui.xml >/dev/null 2>&1
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml "smoke/$1.xml" >/dev/null 2>&1 && break
    sleep 5
  done
  touch "smoke/$1.xml"
  echo "=== Tela ($1) ==="
  grep -o 'text="[^"]*"\|content-desc="[^"]*"' "smoke/$1.xml" | grep -v '=""' | head -40 || true
}
# Espera (até 6 min) a tela de preparação, a tela inicial ou um erro.
touch smoke/inicio.xml
for i in $(seq 1 18); do
  sleep 20
  textos inicio
  if grep -q "Preparando o aplicativo\|Tudo pronto\|Início\|Não foi possível iniciar" smoke/inicio.xml; then break; fi
done
adb exec-out screencap -p > smoke/tela1.png
sleep 90
adb exec-out screencap -p > smoke/tela2.png
textos depois
adb logcat -d > smoke/logcat.txt
echo "=== Erros do app no logcat ==="
grep -E "FATAL|AndroidRuntime: (FATAL|Caused)|[ /]flutter *:|sqflite|SQLite" smoke/logcat.txt | grep -v uiautomator | head -60 || true
if grep -q "Não foi possível iniciar" smoke/inicio.xml smoke/depois.xml; then echo "App mostrou erro de inicialização"; exit 1; fi
if grep -q "FATAL EXCEPTION" smoke/logcat.txt; then echo "App travou"; exit 1; fi
if ! cat smoke/inicio.xml smoke/depois.xml | grep -q "Preparando o aplicativo\|Tudo pronto\|Início"; then echo "Tela esperada não encontrada"; exit 1; fi
echo "OK: app abriu e iniciou a preparação"
