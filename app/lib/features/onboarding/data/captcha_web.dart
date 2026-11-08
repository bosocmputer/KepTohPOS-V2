import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Cloudflare Turnstile site key (public). Empty means captcha is off, as on
/// local and CI stacks.
const String _kSiteKey = String.fromEnvironment('CAPTCHA_SITE_KEY');
const String _kScriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

@JS('document')
external JSObject get _document;

@JS('turnstile')
external JSObject? get _turnstile;

Future<void>? _loading;

Future<void> _loadScript() => _loading ??= () async {
  final done = Completer<void>();
  // `complete` takes an optional value, so it cannot cross into JS directly.
  void loaded() => done.complete();
  final script =
      _document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS)
        ..setProperty('src'.toJS, _kScriptUrl.toJS)
        ..setProperty('async'.toJS, true.toJS)
        ..setProperty('onload'.toJS, loaded.toJS)
        ..setProperty(
          'onerror'.toJS,
          (() => done.completeError(StateError('captcha script failed'))).toJS,
        );
  _document
      .getProperty<JSObject>('head'.toJS)
      .callMethod<JSAny?>('appendChild'.toJS, script);
  await done.future;
}();

/// A one-time Turnstile token for the next Auth call, or `null` when captcha
/// is off. Most people see nothing; Cloudflare shows a checkbox at the bottom
/// of the screen only when it is unsure.
Future<String?> captchaToken() async {
  if (_kSiteKey.isEmpty) return null;
  try {
    await _loadScript();
  } on Object {
    _loading = null;
    rethrow;
  }
  final turnstile = _turnstile!;
  final box = _document.callMethod<JSObject>('createElement'.toJS, 'div'.toJS);
  box
      .getProperty<JSObject>('style'.toJS)
      .setProperty(
        'cssText'.toJS,
        'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);'
                'z-index:2147483647'
            .toJS,
      );
  _document
      .getProperty<JSObject>('body'.toJS)
      .callMethod<JSAny?>('appendChild'.toJS, box);
  final token = Completer<String>();
  final options = JSObject()
    ..setProperty('sitekey'.toJS, _kSiteKey.toJS)
    ..setProperty('language'.toJS, 'th'.toJS)
    ..setProperty('appearance'.toJS, 'interaction-only'.toJS)
    ..setProperty(
      'callback'.toJS,
      ((JSString t) {
        if (!token.isCompleted) token.complete(t.toDart);
      }).toJS,
    )
    ..setProperty(
      'error-callback'.toJS,
      (() {
        if (!token.isCompleted) {
          token.completeError(StateError('captcha failed'));
        }
      }).toJS,
    );
  try {
    turnstile.callMethod<JSAny?>('render'.toJS, box, options);
    return await token.future.timeout(const Duration(minutes: 2));
  } finally {
    box.callMethod<JSAny?>('remove'.toJS);
  }
}
