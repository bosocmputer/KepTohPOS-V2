import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target);

/// Opens [url] in a new browser tab, or hands it to the app that owns it
/// (LINE for `line.me` links on a phone).
void openUrl(String url) => _open(url.toJS, '_blank'.toJS);
