import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/obd_model.dart';
import '../core/dtc_decoder.dart';

class FaultCodesPage extends StatelessWidget {
  const FaultCodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<OBDModel>(context);
    final dtcs = model.dtcs;

    // Debug prints for DTCs and a few live values
    try {
      debugPrint('FAULTS: dtcs=${dtcs.join(', ')}');
      debugPrint(
        'FAULTS: rpm=${model.values['rpm']} battery=${model.values['battery_v']} throttle=${model.values['throttle_%']}',
      );
    } catch (_) {}

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: model.connected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.signal_wifi_off, color: Colors.red),
                title: Text(
                  model.connected ? 'Adapter connected' : 'Not connected',
                ),
                subtitle: Text(
                  model.connected
                      ? 'Tap a button to read or clear faults'
                      : 'Connect to an adapter first',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: model.connected
                          ? () => model.requestFaults()
                          : null,
                      child: const Text('Read'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: model.connected
                          ? () => model.clearFaults()
                          : null,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dtcs.isEmpty
                  ? Center(
                      child: Text(
                        model.connected
                            ? 'No DTCs found'
                            : 'Connect to adapter and read DTCs',
                      ),
                    )
                  : ListView.builder(
                      itemCount: dtcs.length,
                      itemBuilder: (ctx, i) {
                        final code = dtcs[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.code),
                            title: Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: FutureBuilder<String>(
                              future: DTCDecoder.instance.decode(code),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text('Decoding...');
                                }
                                if (snap.hasError) {
                                  return Text('Error: ${snap.error}');
                                }
                                return Text(snap.data ?? 'No description');
                              },
                            ),
                            onTap: () {
                              // Could open a web lookup or local DB
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
