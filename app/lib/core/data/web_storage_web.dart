import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('window.localStorage.setItem')
external void _setItem(JSString key, JSString value);

@JS('window.localStorage.removeItem')
external void _removeItem(JSString key);

/// Reads [key] from `window.localStorage`, returning `null` if unavailable.
String? readWebLocalStorage(String key) {
  try {
    return _getItem(key.toJS)?.toDart;
  } on Object {
    return null;
  }
}

/// Writes [value] to `window.localStorage` under [key].
void writeWebLocalStorage(String key, String value) {
  try {
    _setItem(key.toJS, value.toJS);
  } on Object {
    // Ignore storage quota or private-mode restrictions.
  }
}

/// Removes [key] from `window.localStorage`.
void removeWebLocalStorage(String key) {
  try {
    _removeItem(key.toJS);
  } on Object {
    // Ignore storage restrictions.
  }
}
