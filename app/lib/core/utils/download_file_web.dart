import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Saves [content] as a UTF-8 text file named [filename] through a temporary
/// `<a download>` click on a Blob URL.
void downloadTextFile(String filename, String content) {
  final blob = (globalContext['Blob']! as JSFunction)
      .callAsConstructor<JSObject>(
        <JSAny>[content.toJS].toJS,
        <String, String>{'type': 'text/csv;charset=utf-8'}.jsify(),
      );
  final urls = globalContext['URL']! as JSObject;
  final url = urls.callMethod<JSString>('createObjectURL'.toJS, blob);
  (globalContext['document']! as JSObject).callMethod<JSObject>(
      'createElement'.toJS,
      'a'.toJS,
    )
    ..['href'] = url
    ..['download'] = filename.toJS
    ..callMethod<JSAny?>('click'.toJS);
}
