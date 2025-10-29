import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../models/obd_model.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  List<BluetoothDevice> _paired = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Delay prepare until after the first frame so it's safe to use
    // inherited widgets (Theme.of, Provider.of, etc.). Calling context
    // dependent APIs directly in initState can trigger Flutter errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepare();
    });
  }

  Future<void> _ensurePermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final perms = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.location,
      ];
      for (final p in perms) {
        if (await p.status != PermissionStatus.granted) await p.request();
      }
    }
  }

  Future<void> _prepare() async {
    setState(() => _loading = true);
    await _ensurePermissions();
    await _refreshPaired();
    setState(() => _loading = false);
  }

  Future<void> _refreshPaired() async {
    setState(() => _loading = true);
    try {
      final model = Provider.of<OBDModel>(context, listen: false);
      final devices = await model.getPairedDevices();
      setState(() => _paired = devices);
    } catch (_) {
      setState(() => _paired = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<OBDModel>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Adapter'),
        actions: [
          IconButton(
            onPressed: _refreshPaired,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paired.isEmpty
          ? Center(
              // add a child column with text and button to open bluetooth settings
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bluetooth_disabled,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Bluetooth not Opened or No Paired Devices',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Open your Bluetooth then pair your OBD adapter then connect here.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: _paired.length,
              itemBuilder: (ctx, i) {
                final d = _paired[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(d.name ?? 'Unknown'),
                    subtitle: Text(d.address),
                    trailing: model.connected
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check),
                            label: const Text('Connected'),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await model.connectTo(d);
                                // immediate poll
                                model.initializeAdapter();
                                model.poll();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Connect failed: $e')),
                                );
                              }
                            },
                            child: const Text('Connect'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
