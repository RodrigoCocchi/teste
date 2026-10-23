import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.nexusti.office',
  appName: 'Nexus TI',
  webDir: 'out',
  backgroundColor: '#05070d',
  android: {
    // WebView com aceleração de hardware (WebGL) e sem conteúdo misto HTTP.
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: process.env.NODE_ENV !== 'production',
  },
  plugins: {
    SplashScreen: { launchShowDuration: 800, backgroundColor: '#05070d', showSpinner: false },
    StatusBar: { overlaysWebView: true, style: 'DARK', backgroundColor: '#00000000' },
  },
};

export default config;
