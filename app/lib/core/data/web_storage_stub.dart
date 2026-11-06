/// Stub implementation of browser `localStorage` for non-web (VM/test) targets.
String? readWebLocalStorage(String key) => null;

/// Stub implementation of browser `localStorage` write for non-web targets.
void writeWebLocalStorage(String key, String value) {}

/// Stub implementation of browser `localStorage` remove for non-web targets.
void removeWebLocalStorage(String key) {}
