{{flutter_js}}
{{flutter_build_config}}

// CanvasKit comes from this site, not Google's CDN, so the app can start
// offline; no Flutter service worker is registered (web/sw.js is ours).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
