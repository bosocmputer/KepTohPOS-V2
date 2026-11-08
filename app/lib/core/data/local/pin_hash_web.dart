import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('crypto.subtle')
external JSObject get _subtle;

/// PBKDF2-SHA256 with 100,000 rounds through the browser's Web Crypto, so
/// guessing a 4-digit PIN from a copied device takes real time.
Future<String> hashPin(String pin, String salt) async {
  final key = await _subtle.callMethodVarArgs<JSPromise<JSObject>>(
    'importKey'.toJS,
    <JSAny?>[
      'raw'.toJS,
      Uint8List.fromList(utf8.encode(pin)).toJS,
      'PBKDF2'.toJS,
      false.toJS,
      <JSString>['deriveBits'.toJS].toJS,
    ],
  ).toDart;
  final params = JSObject()
    ..setProperty('name'.toJS, 'PBKDF2'.toJS)
    ..setProperty('salt'.toJS, Uint8List.fromList(utf8.encode(salt)).toJS)
    ..setProperty('iterations'.toJS, 100000.toJS)
    ..setProperty('hash'.toJS, 'SHA-256'.toJS);
  final bits = await _subtle.callMethodVarArgs<JSPromise<JSArrayBuffer>>(
    'deriveBits'.toJS,
    <JSAny?>[params, key, 256.toJS],
  ).toDart;
  return base64.encode(bits.toDart.asUint8List());
}
