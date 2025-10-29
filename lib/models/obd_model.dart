import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../core/obd_service.dart';
import '../core/bluetooth_service.dart';
import '../core/log_service.dart';

class OBDModel extends ChangeNotifier {
  final OBDService _obd;
  final BluetoothService _bt;
  final LogService _log;

  Timer? _uiTimer;

  OBDModel(this._obd, this._bt, this._log) {
    // start periodic UI refresh to notify listeners for live data (1 Hz)
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_obd.isConnected) notifyListeners();
    });
  }

  bool get connected => _obd.isConnected;
  bool get connecting => _obd.connecting;
  Map<String, dynamic> get values => _obd.values;
  List<String> get logs => _obd.logs;
  List<String> get dtcs => _obd.getFaults();

  Future<List<BluetoothDevice>> getPairedDevices() => _bt.getBondedDevices();

  Future<void> connectTo(BluetoothDevice device) async {
    await _obd.connect(device);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _obd.disconnect();
    notifyListeners();
  }

  void poll() => _obd.pollAll();

  Future<bool> initializeAdapter() => _obd.initializeAdapter();

  Future<void> sendCustomCommand(String cmd) => _obd.sendCustomCommand(cmd);

  Future<void> requestCarInfo() => _obd.requestCarInfo();

  void requestFaults() {
    _obd.requestFaults();
    notifyListeners();
  }

  void clearFaults() {
    _obd.clearFaults();
    notifyListeners();
  }

  Future<String> exportSnapshotCsv() => _obd.exportCsvSnapshot();

  @override
  void dispose() {
    _uiTimer?.cancel();
    _obd.disposeService();
    super.dispose();
  }
}
