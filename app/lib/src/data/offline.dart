import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'cache:';

/// Server responses saved on the device, as JSON, so they can be shown again with no connection.
class OfflineStore {
  Future<Object?> read(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// Saves [json] under [key]; null removes what was saved.
  Future<void> write(String key, Object? json) async {
    final prefs = await SharedPreferences.getInstance();
    if (json == null) {
      await prefs.remove('$_prefix$key');
    } else {
      await prefs.setString('$_prefix$key', jsonEncode(json));
    }
  }

  Future<bool> has(String key) async => (await SharedPreferences.getInstance()).containsKey('$_prefix$key');

  /// Forgets every saved response, leaving progress and settings alone.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}

/// Whether the app is showing saved data because the last read couldn't reach the server.
class OfflineStatus extends ChangeNotifier {
  bool _offline = false;

  bool get offline => _offline;

  /// A read reached the server.
  void reached() => _set(false);

  /// A read couldn't reach the server and showed a saved copy.
  void fellBack() => _set(true);

  void _set(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }
}

/// A failure to reach the server, as opposed to an answer from it. `ClientException` covers socket errors too.
bool isOfflineError(Object e) => e is http.ClientException || e is TimeoutException;

/// Runs [fetch] and saves its result under [key]. When the server can't be reached, returns the saved copy instead,
/// or rethrows when there is none.
Future<Object?> readThrough({
  required OfflineStore store,
  required OfflineStatus status,
  required String key,
  required Future<Object?> Function() fetch,
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    final result = await fetch().timeout(timeout);
    await store.write(key, result);
    status.reached();
    return result;
  } catch (e) {
    if (!isOfflineError(e)) rethrow;
    final saved = await store.read(key);
    if (saved == null) rethrow;
    status.fellBack();
    return saved;
  }
}
