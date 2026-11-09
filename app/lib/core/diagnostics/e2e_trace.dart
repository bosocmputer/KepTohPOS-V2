// TEMPORARY: remove after M3 login race is found
import 'package:flutter/foundation.dart';

final Stopwatch _clock = Stopwatch()..start();
final List<String> _lines = <String>[];

/// Appends a timestamped line (debug builds only); keeps the last 150.
void e2eTrace(String msg) {
  if (!kDebugMode) return;
  _lines.add('${_clock.elapsedMilliseconds} $msg');
  if (_lines.length > 150) _lines.removeAt(0);
}

List<String> get e2eTraceLines => List<String>.unmodifiable(_lines);
