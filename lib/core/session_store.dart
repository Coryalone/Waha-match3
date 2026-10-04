import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_core.dart';
import 'game_session.dart';

class SessionStore {
  static const _key = 'game_session_v1';

  Future<GameSession?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    try {
      return decode(raw);
    } on FormatException {
      await preferences.remove(_key);
      return null;
    } on ArgumentError {
      await preferences.remove(_key);
      return null;
    }
  }

  Future<void> save(GameSession session) async {
    await saveEncoded(encode(session));
  }

  Future<void> saveEncoded(String data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, data);
  }

  static String encode(GameSession session) => jsonEncode({
    'version': 1,
    'level': session.level,
    'score': session.score,
    'cells': session.board.cells,
    'soundEnabled': session.soundEnabled,
  });

  static GameSession decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        throw const FormatException('Unknown save format');
      }
      final rows = value['cells'];
      if (rows is! List) throw const FormatException('Missing board');
      final cells = rows
          .map((row) => (row as List).map((gem) => gem as int).toList())
          .toList();
      return GameSession.restore(
        level: value['level'] as int,
        score: value['score'] as int,
        cells: cells,
        soundEnabled: value['soundEnabled'] as bool,
      );
    } on TypeError {
      throw const FormatException('Invalid save data');
    } on CastError {
      throw const FormatException('Invalid save data');
    }
  }
}

