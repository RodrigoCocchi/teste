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
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml "smoke/$1.xml" >/dev/null 2>&1 || true
  echo "=== Tela ($1) ==="
  grep -o 'text="[^"]*"\|content-desc="[^"]*"' "smoke/$1.xml" | grep -v '=""' | head -40 || true
}
sleep 25
adb exec-out screencap -p > smoke/tela1.png
textos inicio
sleep 120
adb exec-out screencap -p > smoke/tela2.png
textos depois
adb logcat -d > smoke/logcat.txt
echo "=== Erros do app no logcat ==="
grep -E "FATAL|AndroidRuntime|E/flutter" smoke/logcat.txt | head -40 || true
if grep -q "Não foi possível iniciar" smoke/inicio.xml; then echo "App mostrou erro de inicialização"; exit 1; fi
if grep -q "FATAL EXCEPTION" smoke/logcat.txt; then echo "App travou"; exit 1; fi
if ! grep -q "Preparando o aplicativo\|Início" smoke/inicio.xml; then echo "Tela esperada não encontrada"; exit 1; fi
echo "OK: app abriu e iniciou a preparação"
