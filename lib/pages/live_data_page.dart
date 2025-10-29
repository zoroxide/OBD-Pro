import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/obd_model.dart';
import 'connect_page.dart';
import '../widgets/obd_value_tile.dart';
import '../widgets/obd_status_card.dart';

class LiveDataPage extends StatefulWidget {
  const LiveDataPage({super.key});

  @override
  State<LiveDataPage> createState() => _LiveDataPageState();
}

class _LiveDataPageState extends State<LiveDataPage> {
  // bool _fetching = false;

  // Future<void> _fetchInfo(OBDModel model) async {
  //   setState(() => _fetching = true);

  //   await model.requestCarInfo();

  //   // wait up to 6s for VIN to appear
  //   final deadline = DateTime.now().add(const Duration(seconds: 6));
  //   while (mounted && DateTime.now().isBefore(deadline)) {
  //     if ((model.values['vin'] ?? '').toString().isNotEmpty) break;
  //     await Future.delayed(const Duration(milliseconds: 250));
  //   }

  //   debugPrint(
  //     'FETCH: vin=${model.values['vin']} battery=${model.values['battery_v']}',
  //   );
  //   if (mounted) setState(() => _fetching = false);
  // }

  String _wmi(String vin) => vin.length >= 3 ? vin.substring(0, 3) : 'Unknown';
  String _modelYear(String vin) {
    if (vin.length < 10) return 'Unknown';
    final code = vin[9].toUpperCase();
    const map = {
      'A': 2010,
      'B': 2011,
      'C': 2012,
      'D': 2013,
      'E': 2014,
      'F': 2015,
      'G': 2016,
      'H': 2017,
      'J': 2018,
      'K': 2019,
      'L': 2020,
      'M': 2021,
      'N': 2022,
      'P': 2023,
      'R': 2024,
      'S': 2025,
      'T': 2026,
      'V': 2027,
      'W': 2028,
      'X': 2029,
      'Y': 2030,
    };
    return map[code]?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<OBDModel>(context);

    // If not connected, show a simple placeholder with a Connect button
    if (!model.connected) {
      return SafeArea(
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
                      'Adapter not connected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect to your Bluetooth OBD adapter to view live data.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConnectPage()),
                      ),
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Open Connect Page'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final entries = [
      {'label': 'RPM', 'key': 'rpm'},
      {'label': 'Speed (km/h)', 'key': 'speed_kmh'},
      {'label': 'Coolant (°C)', 'key': 'coolant_c'},
      {'label': 'Intake (°C)', 'key': 'intake_temp_c'},
      {'label': 'Throttle (%)', 'key': 'throttle_%'},
      {'label': 'Engine Load (%)', 'key': 'engine_load_%'},
      {'label': 'MAF (g/s)', 'key': 'maf_gps'},
      {'label': 'Fuel (%)', 'key': 'fuel_%'},
      {'label': 'Fuel Pressure (kPa)', 'key': 'fuel_pressure_kpa'},
      {'label': 'Battery (V)', 'key': 'battery_v'},
    ];

    final vin = (model.values['vin'] ?? '').toString();
    final wmi = _wmi(vin);
    final year = _modelYear(vin);

    return RefreshIndicator(
      onRefresh: () async {
        model.poll();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          // Vehicle info card
          // SliverToBoxAdapter(
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //     child: Card(
          //       elevation: 2,
          //       child: Padding(
          //         padding: const EdgeInsets.all(12.0),
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Row(
          //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //               children: [
          //                 const Text(
          //                   'Vehicle Info',
          //                   style: TextStyle(fontWeight: FontWeight.bold),
          //                 ),
          //                 ElevatedButton.icon(
          //                   onPressed: _fetching
          //                       ? null
          //                       : () => _fetchInfo(model),
          //                   icon: _fetching
          //                       ? const SizedBox(
          //                           width: 16,
          //                           height: 16,
          //                           child: CircularProgressIndicator(
          //                             strokeWidth: 2,
          //                           ),
          //                         )
          //                       : const Icon(Icons.download),
          //                   label: const Text('Fetch Data'),
          //                 ),
          //               ],
          //             ),
          //             const SizedBox(height: 8),
          //             Wrap(
          //               runSpacing: 8,
          //               children: [
          //                 Text('VIN: ${vin.isNotEmpty ? vin : 'Unknown'}'),
          //                 Text('WMI: ${vin.isNotEmpty ? wmi : 'Unknown'}'),
          //                 Text(
          //                   'Model Year: ${vin.isNotEmpty ? year : 'Unknown'}',
          //                 ),
          //                 if ((model.values['battery_v'] ?? '') != '')
          //                   Text('Battery: ${model.values['battery_v']} V'),
          //               ],
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          SliverToBoxAdapter(child: OBDStatusCard()),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              childAspectRatio: 1.15,
              children: entries.map((e) {
                final val = model.values[e['key']];
                debugPrint('LIVE TILE: ${e['label']}: $val');
                return OBDValueTile(e['label']!, val);
              }).toList(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Logs',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          reverse: true,
                          itemCount: model.logs.length,
                          itemBuilder: (ctx, i) => Text(
                            model.logs[i],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
