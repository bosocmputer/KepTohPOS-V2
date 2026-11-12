import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

/// Opens a browser `<input type="file" accept="image/*">` dialog, resizes the
/// chosen image onto a white-backed `<canvas>` (max 240x240 px so
/// `localStorage` stays compact and transparent PNGs render cleanly on thermal
/// paper), and returns a `data:image/png;base64,...` URL.
Future<String?> pickShopLogoDataUrlImpl() {
  final completer = Completer<String?>();
  final doc = globalContext['document']! as JSObject;
  final input = doc.callMethod<JSObject>('createElement'.toJS, 'input'.toJS)
    ..['type'] = 'file'.toJS
    ..['accept'] = 'image/*'.toJS;

  void finish(String? result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  input['onchange'] = ((JSAny? _) {
    final files = input['files'] as JSObject?;
    final len = (files?['length'] as JSNumber?)?.toDartInt ?? 0;
    if (files == null || len == 0) {
      finish(null);
      return;
    }
    final file = files.callMethod<JSObject>('item'.toJS, 0.toJS);
    final readerCtor = globalContext['FileReader']! as JSFunction;
    final reader = readerCtor.callAsConstructor<JSObject>();
    reader['onerror'] = ((JSAny? _) => finish(null)).toJS;
    reader['onload'] = ((JSAny? _) {
      final rawUrl = (reader['result'] as JSString?)?.toDart;
      if (rawUrl == null || rawUrl.isEmpty) {
        finish(null);
        return;
      }
      unawaited(_normalizeLogoViaCanvas(doc, rawUrl).then(finish));
    }).toJS;
    reader.callMethod<JSAny?>('readAsDataURL'.toJS, file);
  }).toJS;

  input.callMethod<JSAny?>('click'.toJS);
  return completer.future;
}

Future<String?> _normalizeLogoViaCanvas(JSObject doc, String srcDataUrl) {
  final completer = Completer<String?>();
  final imgCtor = globalContext['Image']! as JSFunction;
  final img = imgCtor.callAsConstructor<JSObject>();
  img['onerror'] = ((JSAny? _) {
    if (!completer.isCompleted) completer.complete(srcDataUrl);
  }).toJS;
  img['onload'] = ((JSAny? _) {
    try {
      final nw = ((img['naturalWidth'] as JSNumber?)?.toDartInt ?? 200).clamp(
        1,
        4096,
      );
      final nh = ((img['naturalHeight'] as JSNumber?)?.toDartInt ?? 200).clamp(
        1,
        4096,
      );
      const maxDim = 240;
      final scale = math.min(1, maxDim / math.max(nw, nh));
      final tw = math.max(1, (nw * scale).round());
      final th = math.max(1, (nh * scale).round());

      final canvas =
          doc.callMethod<JSObject>('createElement'.toJS, 'canvas'.toJS)
            ..['width'] = tw.toJS
            ..['height'] = th.toJS;
      canvas.callMethod<JSObject>('getContext'.toJS, '2d'.toJS)
        ..['fillStyle'] = '#FFFFFF'.toJS
        ..callMethod<JSAny?>('fillRect'.toJS, 0.toJS, 0.toJS, tw.toJS, th.toJS)
        ..callMethodVarArgs<JSAny?>('drawImage'.toJS, <JSAny?>[
          img,
          0.toJS,
          0.toJS,
          tw.toJS,
          th.toJS,
        ]);
      final out = canvas
          .callMethod<JSString>('toDataURL'.toJS, 'image/png'.toJS)
          .toDart;
      if (!completer.isCompleted) completer.complete(out);
    } on Object {
      if (!completer.isCompleted) completer.complete(srcDataUrl);
    }
  }).toJS;
  img['src'] = srcDataUrl.toJS;
  return completer.future;
}
