import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/obd_model.dart';

class OBDStatusCard extends StatelessWidget {
  const OBDStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<OBDModel>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        child: ListTile(
          leading: model.connected
              ? const Icon(
                  Icons.bluetooth_connected,
                  color: Colors.green,
                  size: 36,
                )
              : const Icon(Icons.bluetooth_disabled, size: 36),
          title: Text(
            model.connected
                ? 'Connected'
                : model.connecting
                ? 'Connecting...'
                : 'Not connected',
          ),
          subtitle: Text(
            model.connected
                ? 'Streaming live OBD data'
                : 'Use Connect to pair and connect',
          ),
          trailing: model.connected
              ? ElevatedButton(
                  onPressed: () => model.disconnect(),
                  child: const Text('Disconnect'),
                )
              : null,
        ),
      ),
    );
  }
}
