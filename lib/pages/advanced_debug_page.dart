import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/obd_model.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AdvancedDebugPage extends StatefulWidget {
  const AdvancedDebugPage({super.key});

  @override
  State<AdvancedDebugPage> createState() => _AdvancedDebugPageState();
}

class _AdvancedDebugPageState extends State<AdvancedDebugPage> {
  final _cmdController = TextEditingController();
  bool _initializing = false;
  String? _initResultPath;
  bool _initSuccess = false;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<OBDModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Debug')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: model.connected
                    ? const Icon(Icons.bluetooth_connected, color: Colors.green)
                    : const Icon(Icons.bluetooth_disabled),
                title: Text(model.connected ? 'Connected' : 'Not connected'),
                subtitle: Text(
                  model.connected
                      ? 'Adapter ready'
                      : 'Connect via the Connect page',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _initializing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: SpinKitFadingCircle(
                              size: 18,
                              itemBuilder: _dotBuilder,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Initialize OBD Connection'),
                    onPressed: model.connected && !_initializing
                        ? () async {
                            setState(() {
                              _initializing = true;
                              _initResultPath = null;
                            });
                            final ok = await model.initializeAdapter();
                            setState(() {
                              _initializing = false;
                              _initSuccess = ok;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Initialize succeeded'
                                      : 'Initialize seemed to fail',
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: model.connected ? () => model.poll() : null,
                  child: const Text('Poll Now'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cmdController,
              decoration: const InputDecoration(
                labelText: 'Custom OBD Command (e.g., 010C or ATZ)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: model.connected
                        ? () async {
                            final cmd = _cmdController.text.trim();
                            if (cmd.isEmpty) return;
                            await model.sendCustomCommand(cmd);
                            _cmdController.clear();
                          }
                        : null,
                    child: const Text('Send Command'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: model.connected
                      ? () async {
                          final path = await model.exportSnapshotCsv();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved CSV to: $path')),
                          );
                        }
                      : null,
                  child: const Text('Save CSV Snapshot'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Logs:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Consumer<OBDModel>(
                    builder: (ctx, m, _) => ListView.builder(
                      reverse: true,
                      itemCount: m.logs.length,
                      itemBuilder: (ctx, i) => Text(
                        m.logs[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _dotBuilder(BuildContext _, int __) => DecoratedBox(
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
  );
}
