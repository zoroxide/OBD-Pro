import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoPoll = true;
  bool _saveCsvOnSnapshot = true;
  String _pollInterval = '1s';

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModeModel>(context, listen: true);
    final current = themeModel.mode;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: current,
              onChanged: (m) => themeModel.setMode(m ?? ThemeMode.system),
              title: const Text('System default'),
              subtitle: const Text('Follow device light/dark setting'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: current,
              onChanged: (m) => themeModel.setMode(m ?? ThemeMode.light),
              title: const Text('Light'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: current,
              onChanged: (m) => themeModel.setMode(m ?? ThemeMode.dark),
              title: const Text('Dark'),
            ),
            const Divider(height: 24),
            SwitchListTile(
              value: _autoPoll,
              onChanged: (v) => setState(() => _autoPoll = v),
              title: const Text('Auto poll live values'),
              subtitle: const Text(
                'If enabled the app will poll OBD values periodically',
              ),
            ),
            SwitchListTile(
              value: _saveCsvOnSnapshot,
              onChanged: (v) => setState(() => _saveCsvOnSnapshot = v),
              title: const Text('Save CSV when taking snapshot'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Poll interval',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButton<String>(
              value: _pollInterval,
              items: const [
                DropdownMenuItem(value: '1s', child: Text('1 second')),
                DropdownMenuItem(value: '2s', child: Text('2 seconds')),
                DropdownMenuItem(value: '5s', child: Text('5 seconds')),
              ],
              onChanged: (v) =>
                  setState(() => _pollInterval = v ?? _pollInterval),
            ),
            const Spacer(),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // For now just show snackbar; persistence can be implemented later
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings saved (not persisted)'),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
