#!/usr/bin/env bash
# Instala o APK do Nexus TI no emulador, abre o app e confere se o escritório carregou.
set -u
APK=apps/office/android/app/build/outputs/apk/release/nexus-ti.apk
PKG=com.nexusti.office
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
# Espera (até 4 min) o escritório aparecer: título e selo "Demo local"/"Ao vivo".
touch smoke/inicio.xml
for _ in $(seq 1 12); do
  sleep 20
  textos inicio
  if grep -q "Nexus TI" smoke/inicio.xml && grep -q "Demo local\|Ao vivo\|Conectando" smoke/inicio.xml; then break; fi
done
adb exec-out screencap -p > smoke/tela1.png
sleep 45
adb exec-out screencap -p > smoke/tela2.png
textos depois
adb logcat -d > smoke/logcat.txt
echo "=== Erros no logcat ==="
grep -E "FATAL|AndroidRuntime|Capacitor/Console.*(Error|error)|chromium.*ERROR" smoke/logcat.txt | head -40 || true
if grep -q "FATAL EXCEPTION" smoke/logcat.txt; then echo "App travou"; exit 1; fi
if ! adb shell pidof "$PKG" >/dev/null; then echo "App fechou sozinho"; exit 1; fi
if ! cat smoke/inicio.xml smoke/depois.xml | grep -q "Nexus TI"; then echo "Escritório não apareceu"; exit 1; fi
if grep -q "WebGL\|Error creating WebGL context" smoke/logcat.txt; then echo "Aviso: verifique mensagens de WebGL no logcat"; fi
echo "OK: app abriu e o escritório carregou"
