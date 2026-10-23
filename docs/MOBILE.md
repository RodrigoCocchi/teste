# App Android e qualidade de mídia

## Como o APK é feito

`apps/office` é um Next.js com `output: 'export'`: o build gera HTML/JS/CSS estáticos em
`apps/office/out`. O **Capacitor** copia essa pasta para dentro do projeto Android
(`apps/office/android`) e o app abre tudo num WebView com aceleração de hardware.
Resultado: **o mesmo código** do escritório 3D roda na web e no APK.

Regras que isso impõe:

- Nada de SSR, `route handlers` ou `server actions` no `office` — toda lógica fica na API.
- A URL da API é fixada no build (`NEXT_PUBLIC_API_URL`).
- Login no app via token bearer (Better Auth `bearer`): header `Authorization` no REST e
  `?token=` no WebSocket. As origens `capacitor://localhost` e `https://localhost` estão em
  `TRUSTED_ORIGINS`.

## Gerar o APK

**CI (recomendado)**: `.github/workflows/nexus-apk.yml` roda a cada push: testes, build,
APK release assinado, **teste no emulador Android** (`.github/scripts/nexus-smoke.sh`, com
screenshots no artefato `nexus-smoke-test`) e publica na release `nexus-apk-latest`.

- Sem a variável `NEXT_PUBLIC_API_URL` o APK sai em **modo demo local** (funciona offline).
- Assinatura: crie os segredos `NEXUS_KEYSTORE_BASE64` (keystore em base64) e
  `NEXUS_KEYSTORE_PASSWORD` (alias `nexus`). Sem eles, cada build usa uma chave temporária e
  é preciso desinstalar a versão anterior antes de instalar a nova.

  ```bash
  keytool -genkeypair -keystore nexus.jks -alias nexus -keyalg RSA -keysize 2048 -validity 10000
  base64 -w0 nexus.jks   # conteúdo do segredo NEXUS_KEYSTORE_BASE64
  ```

**Local** (Android Studio + SDK 36 + JDK 21):

```bash
NEXT_PUBLIC_API_URL=https://sua-api pnpm --filter @nexus/office android:sync
cd apps/office/android && ./gradlew assembleDebug
# APK: apps/office/android/app/build/outputs/apk/debug/app-debug.apk
```

No emulador, `http://10.0.2.2:4000` aponta para a API rodando no seu computador.

Release (Fase 8): assinar com keystore guardada em segredo do GitHub e gerar AAB para a Play Store.

## Padrão de qualidade de mídia

| Tipo                      | Master (em `assets/`, Git LFS)       | Entrega                                                                   |
| ------------------------- | ------------------------------------ | ------------------------------------------------------------------------- |
| Imagens de UI / marketing | PNG 16-bit ou TIFF sem perda         | AVIF (q≈80) + WebP (q≈90), 1x/2x/3x via `srcset`                          |
| Texturas 3D               | PNG/EXR 4K                           | KTX2: UASTC (normal, telas, rostos), ETC1S (difusas secundárias); mipmaps |
| Modelos 3D                | `.blend`                             | GLB com Draco + KTX2 (gltf-transform)                                     |
| HDRI                      | EXR 4K–8K                            | HDR 2K para web/celular, 4K no modo cinematográfico                       |
| Vídeo                     | ProRes / gravação lossless 4K 60 fps | AV1 + H.264 (fallback), 16:9 (3840×2160) e 9:16 (2160×3840)               |

No celular a qualidade adaptativa (`PerformanceMonitor`) reduz primeiro sombras e
pós-processamento, e só depois resolução de render — nunca a resolução das texturas.
