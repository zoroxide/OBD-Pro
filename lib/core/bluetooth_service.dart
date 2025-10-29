// core/bluetooth_service.dart
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;

  /// Returns list of bonded (paired) devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final bonded = await _bt.getBondedDevices();
      return bonded;
    } catch (_) {
      return [];
    }
  }

  /// Connect to device by address and return BluetoothConnection
  Future<BluetoothConnection> connectToAddress(String address) {
    return BluetoothConnection.toAddress(address);
  }

  /// Convenience: enable bluetooth (if needed) - optional
  Future<bool?> requestEnable() => _bt.requestEnable();
}
