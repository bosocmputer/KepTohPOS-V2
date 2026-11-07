import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// An HTTP client that reports whether any request is still in flight.
///
/// Every Supabase client on the device shares one instance, so the screen can
/// show that it is waiting and block a second tap that would repeat a sale.
class NetworkActivity extends http.BaseClient {
  new([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  int _pending = 0;

  /// `true` while a request has not finished, including reading its body.
  ValueListenable<bool> get busy => _busy;

  void _start() => _busy.value = ++_pending > 0;

  void _end() => _busy.value = --_pending > 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _start();
    var ended = false;
    void end() {
      if (ended) return;
      ended = true;
      _end();
    }

    final http.StreamedResponse res;
    try {
      res = await _inner.send(request);
    } on Object {
      end();
      rethrow;
    }
    final body = res.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleError: (error, stack, sink) {
          end();
          sink.addError(error, stack);
        },
        handleDone: (sink) {
          end();
          sink.close();
        },
      ),
    );
    return http.StreamedResponse(
      body,
      res.statusCode,
      contentLength: res.contentLength,
      request: res.request,
      headers: res.headers,
      isRedirect: res.isRedirect,
      persistentConnection: res.persistentConnection,
      reasonPhrase: res.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    _busy.dispose();
  }
}
