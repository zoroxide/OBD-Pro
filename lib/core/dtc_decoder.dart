import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class DTCDecoder {
  DTCDecoder._();

  static final DTCDecoder _instance = DTCDecoder._();
  static DTCDecoder get instance => _instance;

  Map<String, String>? _map;

  Future<void> loadIfNeeded() async {
    if (_map != null) return;
    try {
      final s = await rootBundle.loadString('assets/dtc_messages.json');
      final dynamic parsed = json.decode(s);
      _map = Map<String, String>.from(parsed as Map);
    } catch (e) {
      _map = {};
    }
  }

  /// Decode a DTC code to a human readable message. Supports wildcard keys
  /// in the JSON like 'P0xx' where 'x' matches any hex digit.
  Future<String> decode(String code) async {
    await loadIfNeeded();
    final map = _map ?? {};
    final up = code.toUpperCase();

    // Exact match first
    if (map.containsKey(up)) return map[up]!;

    // Build patterns from keys (wildcard 'x' -> hex char)
    // prefer more specific (fewer x) keys first
    final entries = map.keys.toList()
      ..sort((a, b) {
        final ax = 'x'.allMatches(a.toLowerCase()).length;
        final bx = 'x'.allMatches(b.toLowerCase()).length;
        return ax.compareTo(bx);
      });

    for (final k in entries) {
      final pattern =
          '^' + RegExp.escape(k).replaceAll('x', '[0-9A-Fa-f]') + r'$';
      final reg = RegExp(pattern, caseSensitive: false);
      if (reg.hasMatch(up)) return map[k] ?? '';
    }

    return 'Unknown DTC ($code)';
  }
}
