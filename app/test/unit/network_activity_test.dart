import 'dart:async';

import 'package:app/core/data/supabase/network_activity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('busy stays on until every response body has been read', () async {
    // Arrange
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final activity = NetworkActivity(
      MockClient((req) => req.url.path == '/a' ? first.future : second.future),
    );
    final seen = <bool>[];
    activity.busy.addListener(() => seen.add(activity.busy.value));

    // Act
    final a = activity.get(Uri.parse('https://x.test/a'));
    final b = activity.get(Uri.parse('https://x.test/b'));
    await Future<void>.delayed(Duration.zero);
    final whileBoth = activity.busy.value;
    first.complete(http.Response('a', 200));
    await a;
    final whileOne = activity.busy.value;
    second.complete(http.Response('b', 200));
    await b;

    // Assert
    expect(whileBoth, isTrue);
    expect(whileOne, isTrue);
    expect(activity.busy.value, isFalse);
    expect(seen.last, isFalse);
  });

  test('a quiet background request does not block the screen', () async {
    // Arrange
    final reply = Completer<http.Response>();
    final activity = NetworkActivity(MockClient((_) => reply.future));

    // Act
    final call = activity.quietly(
      () => activity.get(Uri.parse('https://x.test/reload')),
    );
    await Future<void>.delayed(Duration.zero);
    final whileWaiting = activity.busy.value;
    reply.complete(http.Response('ok', 200));
    await call;

    // Assert
    expect(whileWaiting, isFalse);
    expect(activity.busy.value, isFalse);
    expect(activity.reachable.value, isTrue);
  });

  test('a failed request does not leave busy stuck on', () async {
    // Arrange
    final activity = NetworkActivity(
      MockClient((_) async => throw http.ClientException('offline')),
    );

    // Act
    await expectLater(
      activity.get(Uri.parse('https://x.test/a')),
      throwsA(isA<http.ClientException>()),
    );

    // Assert
    expect(activity.busy.value, isFalse);
  });

  test(
    'reachable goes off when a request cannot connect, on with any reply',
    () async {
      // Arrange
      var down = true;
      final activity = NetworkActivity(
        MockClient((req) async {
          if (down) throw http.ClientException('Failed to fetch', req.url);
          return http.Response('no', 401);
        }),
      );
      final start = activity.reachable.value;

      // Act
      await expectLater(
        activity.get(Uri.parse('https://x.test/a')),
        throwsA(isA<http.ClientException>()),
      );
      final whileDown = activity.reachable.value;
      down = false;
      await activity.get(Uri.parse('https://x.test/a'));

      // Assert: a 401 still proves the server is reachable.
      expect(start, isTrue);
      expect(whileDown, isFalse);
      expect(activity.reachable.value, isTrue);
    },
  );

  test(
    'quietly suppresses busy across multiple sequential background sync calls',
    () async {
      // Arrange
      final activity = NetworkActivity(
        MockClient((_) async => http.Response('ok', 200)),
      );
      final seenBusy = <bool>[];
      activity.busy.addListener(() => seenBusy.add(activity.busy.value));

      // Act
      await activity.quietly(() async {
        await activity.hold(() async {
          await activity.post(Uri.parse('https://x.test/rpc/open_table'));
          await activity.post(Uri.parse('https://x.test/rpc/settle_bill'));
          await activity.get(Uri.parse('https://x.test/reload'));
        });
      });

      // Assert
      expect(seenBusy, isEmpty);
      expect(activity.busy.value, isFalse);
      expect(activity.reachable.value, isTrue);
    },
  );
}
