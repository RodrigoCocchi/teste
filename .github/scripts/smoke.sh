#!/usr/bin/env bash
# Instala o APK no emulador, abre o app e confere se a tela inicial aparece.
set -u
APK=build/app/outputs/flutter-apk/app-release.apk
PKG=br.pessoal.biblia_hinos_ccb
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 30
mkdir -p smoke
adb exec-out screencap -p > smoke/tela.png
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
adb pull /sdcard/ui.xml smoke/ui.xml >/dev/null 2>&1 || true
adb logcat -d > smoke/logcat.txt
echo "=== Textos na tela ==="
grep -o 'text="[^"]*"\|content-desc="[^"]*"' smoke/ui.xml | grep -v '=""' | head -40 || true
echo "=== Erros no logcat ==="
grep -E "FATAL|AndroidRuntime|flutter|E/flutter|Exception" smoke/logcat.txt | head -60 || true
if grep -q "Não foi possível iniciar" smoke/ui.xml; then echo "App mostrou erro de inicialização"; exit 1; fi
if ! grep -q "Início" smoke/ui.xml; then echo "Tela inicial não encontrada"; exit 1; fi
echo "OK: tela inicial aberta"
