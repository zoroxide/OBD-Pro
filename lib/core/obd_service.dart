// core/obd_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';

import 'log_service.dart';
import 'bluetooth_service.dart';

class OBDService {
  final BluetoothService _btService;
  final LogService _logService;

  // Stream to notify listeners when values change (event-driven UI updates)
  final StreamController<void> _onChange = StreamController<void>.broadcast();

  BluetoothConnection? _connection;
  bool connecting = false;
  bool isConnected = false;

  // data
  final Map<String, dynamic> values = {};
  final List<String> logs = [];
  final List<String> dtcList =
      []; // diagnosed trouble codes (strings like P0123)

  // queue & buffer
  final List<String> _cmdQueue = [];
  bool _awaitingResponse = false;
  final StringBuffer _recvBuffer = StringBuffer();
  StreamSubscription<Uint8List>? _sub;
  Timer? _pollTimer;

  // default PIDs to poll
  final List<String> pollCommands = [
    '010C', // RPM
    '010D', // Speed
    '0105', // Coolant temp
    '010F', // Intake air temp
    '0111', // Throttle
    '0104', // Engine load
    '0110', // MAF
    '012F', // Fuel level
    '010A', // Fuel pressure
    'ATRV', // Battery voltage (AT command)
    '0902', // VIN (may be multi-frame)
  ];

  OBDService(this._btService, this._logService);

  /// Stream that emits whenever values or DTCs are updated.
  Stream<void> get onValuesChanged => _onChange.stream;

  Future<void> connect(BluetoothDevice device) async {
    connecting = true;
    _insertLog('Connecting to ${device.name ?? device.address}...');
    _connection = await _btService.connectToAddress(device.address);
    isConnected = true;
    connecting = false;

    _sub = _connection!.input!.listen(_onData, onDone: disconnect);

    // initialize adapter
    await Future.delayed(const Duration(milliseconds: 300));
    await _sendRaw('ATZ'); // reset
    await Future.delayed(const Duration(milliseconds: 800));
    await _sendRaw('ATE0'); // echo off
    await Future.delayed(const Duration(milliseconds: 300));
    await _sendRaw('ATL0'); // linefeeds off
    await Future.delayed(const Duration(milliseconds: 300));
    await _sendRaw('ATS0'); // spaces off
    await Future.delayed(const Duration(milliseconds: 300));
    _recvBuffer.clear();

    // start polling
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => pollAll());

    _insertLog('Connected.');
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _awaitingResponse = false;
    _cmdQueue.clear();
    await _sub?.cancel();
    try {
      await _connection?.finish();
    } catch (_) {}
    _connection = null;
    isConnected = false;
    _insertLog('Disconnected.');
  }

  void pollAll() {
    if (!isConnected) return;
    for (final c in pollCommands) {
      queueCommand(c);
    }
  }

  void queueCommand(String cmd) {
    _cmdQueue.add(cmd);
    _tryFlushQueue();
  }

  void _tryFlushQueue() {
    if (!_awaitingResponse && _cmdQueue.isNotEmpty && _connection != null) {
      final cmd = _cmdQueue.removeAt(0);
      _awaitingResponse = true;
      _sendRaw(cmd);
      Future.delayed(const Duration(seconds: 3), () {
        if (_awaitingResponse) {
          _awaitingResponse = false;
          _insertLog('-- response timeout, continuing');
          _tryFlushQueue();
        }
      });
    }
  }

  Future<void> _sendRaw(String cmd) async {
    if (_connection == null) {
      _insertLog('!! not connected, cannot send: $cmd');
      return;
    }
    final data = utf8.encode('$cmd\r');
    _connection!.output.add(Uint8List.fromList(data));
    await _connection!.output.allSent;
    _insertLog('>> $cmd');
  }

  /// Send custom command immediately (not queued)
  Future<void> sendCustomCommand(String cmd) async {
    await _sendRaw(cmd);
  }

  /// Initialize adapter (AT commands). Returns true if logs show success-ish text.
  Future<bool> initializeAdapter({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_connection == null) return false;
    final before = logs.isNotEmpty ? logs.first : '';
    await _sendRaw('ATZ');
    await Future.delayed(const Duration(milliseconds: 800));
    await _sendRaw('ATE0');
    await Future.delayed(timeout);
    // evaluate logs for ELM/OK presence
    final found = logs.any(
      (l) => l.toUpperCase().contains('ELM') || l.toUpperCase().contains('OK'),
    );
    return found;
  }

  void _onData(Uint8List data) {
    final s = utf8.decode(data, allowMalformed: true);
    _recvBuffer.write(s);
    _insertLog(s, raw: true);

    final bufferStr = _recvBuffer.toString();
    if (bufferStr.contains('>')) {
      final parts = bufferStr.split('>');
      for (var i = 0; i < parts.length - 1; i++) {
        final chunk = parts[i];
        _processChunk(chunk);
      }
      _recvBuffer.clear();
      _recvBuffer.write(parts.last);
      _awaitingResponse = false;
      _tryFlushQueue();
    }
  }

  void _processChunk(String chunk) {
    final cleaned = chunk
        .replaceAll('\r', '\n')
        .replaceAll('\n\n', '\n')
        .trim();
    if (cleaned.isEmpty) return;
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      final up = line.toUpperCase();
      // Store raws that look non-hex (like ELM327, OK)
      if (up.startsWith('ELM') || up == 'OK' || up.startsWith('AT')) {
        _insertLog('<< $line');
        continue;
      }

      // OBD mode 41 (response to 01) / 49 (09) / 43 (03 DTCs)
      if (up.startsWith('41') ||
          up.startsWith('49') ||
          up.startsWith('43') ||
          up.startsWith('NO DATA') ||
          up.startsWith('SEARCHING') ||
          RegExp(r'^[0-9A-F ]+$').hasMatch(line.replaceAll(' ', ''))) {
        _parseOBDLine(line);
      } else {
        _insertLog('<< $line');
      }
    }
  }

  void _parseOBDLine(String line) {
    final l = line.trim();
    _insertLog('<< $l');

    final tokens = l
        .split(RegExp(r'[\s]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return;

    var changed = false;
    try {
      // Mode 01 responses often start with 41
      if (tokens[0] == '41' && tokens.length >= 2) {
        final pid = tokens[1].toUpperCase();
        switch (pid) {
          case '0C': // RPM: ((A*256)+B)/4
            if (tokens.length >= 4) {
              final a = int.parse(tokens[2], radix: 16);
              final b = int.parse(tokens[3], radix: 16);
              values['rpm'] = ((a * 256) + b) / 4.0;
              changed = true;
            }
            break;
          case '0D': // Speed
            if (tokens.length >= 3) {
              values['speed_kmh'] = int.parse(tokens[2], radix: 16);
              changed = true;
            }
            break;
          case '05': // Coolant
            if (tokens.length >= 3) {
              values['coolant_c'] = int.parse(tokens[2], radix: 16) - 40;
              changed = true;
            }
            break;
          case '0F': // Intake air temp
            if (tokens.length >= 3) {
              values['intake_temp_c'] = int.parse(tokens[2], radix: 16) - 40;
              changed = true;
            }
            break;
          case '11': // Throttle
            if (tokens.length >= 3) {
              values['throttle_%'] =
                  (int.parse(tokens[2], radix: 16) * 100) / 255.0;
              changed = true;
            }
            break;
          case '04': // Engine load
            if (tokens.length >= 3) {
              values['engine_load_%'] =
                  (int.parse(tokens[2], radix: 16) * 100) / 255.0;
              changed = true;
            }
            break;
          case '10': // MAF
            if (tokens.length >= 4) {
              final a = int.parse(tokens[2], radix: 16);
              final b = int.parse(tokens[3], radix: 16);
              values['maf_gps'] = ((a * 256) + b) / 100.0;
              changed = true;
            }
            break;
          case '2F': // Fuel level
            if (tokens.length >= 3) {
              values['fuel_%'] =
                  (int.parse(tokens[2], radix: 16) * 100) / 255.0;
              changed = true;
            }
            break;
          case '0A': // Fuel pressure
            if (tokens.length >= 3) {
              values['fuel_pressure_kpa'] = int.parse(tokens[2], radix: 16) * 3;
              changed = true;
            }
            break;
          default:
            values['raw_${pid}'] = tokens.join(' ');
            changed = true;
        }
      } else if (tokens[0] == '49' && tokens.length >= 3) {
        // Mode 09 (e.g., VIN) - 49 02 ...
        final pid = tokens[1].toUpperCase();
        if (pid == '02') {
          final vinHex = tokens.sublist(2).join('');
          final bytes = <int>[];
          final cleaned = vinHex.replaceAll(' ', '');
          for (var i = 0; i + 1 < cleaned.length; i += 2) {
            final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
            if (byte != null && byte != 0) bytes.add(byte);
          }
          final vin = utf8.decode(bytes, allowMalformed: true);
          if (vin.isNotEmpty) {
            values['vin'] = vin;
            changed = true;
          }
        }
      } else if (tokens[0] == '43') {
        // Mode 03 response: DTCs
        final bytes = tokens
            .sublist(1)
            .map((t) => int.tryParse(t, radix: 16) ?? 0)
            .toList();
        final parsed = _parseDTCBytes(bytes);
        if (parsed.isNotEmpty) {
          dtcList.clear();
          dtcList.addAll(parsed);
          values['dtcs'] = List<String>.from(dtcList);
          changed = true;
        }
      } else if (l.toUpperCase().startsWith('NO DATA')) {
        // ignore
      } else {
        // Try to capture battery voltage strings like "12.6V" or "13 V"
        final match = RegExp(
          r'(\d+(?:\.\d+)?)\s*V',
          caseSensitive: false,
        ).firstMatch(l);
        if (match != null) {
          final parsed = double.tryParse(match.group(1) ?? '');
          if (parsed != null) {
            values['battery_v'] = parsed;
            changed = true;
          }
        }
      }
    } catch (e) {
      _insertLog('!! parse error: $e');
      _insertLog('!! line: $l');
    }

    if (changed) {
      try {
        _onChange.add(null);
      } catch (_) {}
    }
  }

  List<String> _parseDTCBytes(List<int> bytes) {
    // DTCs are 2 bytes each. If both zero -> no more.
    final codes = <String>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final b1 = bytes[i];
      final b2 = bytes[i + 1];
      if (b1 == 0 && b2 == 0) continue;
      final firstCharCode = (b1 & 0xC0) >> 6; // first two bits
      final firstChar = ['P', 'C', 'B', 'U'][firstCharCode];
      final digit1 = (b1 & 0x30) >> 4;
      final digit2 = (b1 & 0x0F);
      final digit3 = (b2 & 0xF0) >> 4;
      final digit4 = (b2 & 0x0F);
      final code =
          '$firstChar${digit1.toRadixString(16).toUpperCase()}${digit2.toRadixString(16).toUpperCase()}${digit3.toRadixString(16).toUpperCase()}${digit4.toRadixString(16).toUpperCase()}';
      codes.add(code);
    }
    return codes;
  }

  void _insertLog(String line, {bool raw = false}) {
    final t = DateFormat('HH:mm:ss').format(DateTime.now());
    final entry = '[$t] $line';
    logs.insert(0, entry);
    if (logs.length > 1000) logs.removeRange(1000, logs.length);
  }

  /// Expose DTCs
  List<String> getFaults() => List.unmodifiable(dtcList);

  /// Request DTCs (enqueue Mode 03)
  void requestFaults() {
    queueCommand('03');
  }

  /// Request car info (VIN and battery voltage).
  /// Enqueues an ATRV (adapter voltage) and 0902 (VIN) request and attempts
  /// to flush the command queue so responses arrive quickly.
  Future<void> requestCarInfo() async {
    if (!isConnected) {
      _insertLog('!! not connected, cannot request car info');
      return;
    }
    _insertLog('Requesting car info (VIN & battery)...');
    // Avoid duplicates in queue
    if (!_cmdQueue.contains('ATRV')) _cmdQueue.add('ATRV');
    if (!_cmdQueue.contains('0902')) _cmdQueue.add('0902');
    _tryFlushQueue();
  }

  /// Clear faults (Mode 04)
  void clearFaults() {
    queueCommand('04');
  }

  /// Export a CSV with timestamp and selected live values (uses injected LogService)
  Future<String> exportCsvSnapshot() async {
    final rows = <List<dynamic>>[];
    rows.add([
      'timestamp',
      'rpm',
      'speed_kmh',
      'coolant_c',
      'intake_temp_c',
      'throttle_%',
      'engine_load_%',
      'maf_gps',
      'fuel_%',
      'battery_v',
    ]);
    final ts = DateTime.now().toIso8601String();
    rows.add([
      ts,
      values['rpm']?.toString() ?? '',
      values['speed_kmh']?.toString() ?? '',
      values['coolant_c']?.toString() ?? '',
      values['intake_temp_c']?.toString() ?? '',
      values['throttle_%']?.toString() ?? '',
      values['engine_load_%']?.toString() ?? '',
      values['maf_gps']?.toString() ?? '',
      values['fuel_%']?.toString() ?? '',
      values['battery_v']?.toString() ?? '',
    ]);
    final path = await _logService.saveCsvFromRows(
      rows,
      filenamePrefix: 'obd_snapshot',
    );
    return path;
  }

  /// Dispose when app closes
  Future<void> disposeService() async {
    await disconnect();
    try {
      await _onChange.close();
    } catch (_) {}
  }
}
