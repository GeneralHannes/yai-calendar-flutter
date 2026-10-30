{{flutter_js}}
{{flutter_build_config}}

// No `serviceWorkerSettings`: Flutter's built-in worker is deprecated (a
// self-unregistering stub). The app registers its own `sw.js` from index.html.
_flutter.loader.load();
