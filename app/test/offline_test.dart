import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:selah/src/data/offline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final store = OfflineStore();

  test('store round-trips json', () async {
    await store.write('a', [
      {'x': 1},
    ]);
    expect(await store.read('a'), [
      {'x': 1},
    ]);
    expect(await store.has('a'), isTrue);
  });

  test('writing null removes the saved copy', () async {
    await store.write('a', [1]);
    await store.write('a', null);
    expect(await store.has('a'), isFalse);
  });

  test('corrupt saved json reads as missing', () async {
    SharedPreferences.setMockInitialValues({'cache:a': '{not json'});
    expect(await store.read('a'), isNull);
  });

  test('clear keeps progress', () async {
    SharedPreferences.setMockInitialValues({'cache:a': '[1]', 'progress:s1': '{}', 'church': 'vida'});
    await store.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'progress:s1', 'church'});
  });

  group('readThrough', () {
    late OfflineStatus status;
    setUp(() => status = OfflineStatus());

    Future<Object?> read(Future<Object?> Function() fetch, {Duration timeout = const Duration(seconds: 10)}) =>
        readThrough(store: store, status: status, key: 'k', fetch: fetch, timeout: timeout);

    test('fetch success saves and marks online', () async {
      status.fellBack();
      expect(await read(() async => [1]), [1]);
      expect(await store.read('k'), [1]);
      expect(status.offline, isFalse);
    });

    test('offline error falls back', () async {
      await store.write('k', [1]);
      expect(await read(() async => throw http.ClientException('x')), [1]);
      expect(status.offline, isTrue);
    });

    test('timeout falls back', () async {
      await store.write('k', [1]);
      expect(await read(() => Completer<Object?>().future, timeout: const Duration(milliseconds: 10)), [1]);
      expect(status.offline, isTrue);
    });

    test('offline with nothing saved rethrows', () async {
      await expectLater(read(() async => throw http.ClientException('x')), throwsA(isA<http.ClientException>()));
      expect(status.offline, isFalse);
    });

    test('server errors do not fall back', () async {
      await store.write('k', [1]);
      await expectLater(
        read(() async => throw const PostgrestException(message: 'denied', code: '42501')),
        throwsA(isA<PostgrestException>()),
      );
      expect(await store.read('k'), [1]);
      expect(status.offline, isFalse);
    });
  });

  test('status notifies only on change', () {
    final status = OfflineStatus();
    var calls = 0;
    status.addListener(() => calls++);
    status
      ..fellBack()
      ..fellBack();
    expect(calls, 1);
  });

  test('isOfflineError', () {
    expect(isOfflineError(http.ClientException('x')), isTrue);
    expect(isOfflineError(TimeoutException('t')), isTrue);
    expect(isOfflineError(const PostgrestException(message: 'm')), isFalse);
  });
}
