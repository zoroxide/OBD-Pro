import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/obd_model.dart';
import '../widgets/obd_value_tile.dart';
import '../widgets/obd_status_card.dart';
import 'connect_page.dart';

class LiveDataPage extends StatefulWidget {
  const LiveDataPage({super.key});

  @override
  State<LiveDataPage> createState() => _LiveDataPageState();
}

class _LiveDataPageState extends State<LiveDataPage> {
  // bool _fetching = false;
  String? _selectedKey;
  List<double> _history = [];
  Timer? _historyTimer;
  final int _historyLength = 60; // keep last 60 samples (~1 minute at 1Hz)
  int _chartTick = 0;

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

          // Chart area (appears when a tile is selected)
          if (_selectedKey != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // display friendly label
                                  (entries.firstWhere(
                                            (e) => e['key'] == _selectedKey,
                                            orElse: () => {
                                              'label': _selectedKey ?? '',
                                            },
                                          )['label'] ??
                                          '')
                                      .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  // current value with units
                                  () {
                                    final val = model.values[_selectedKey];
                                    final d = _toDouble(val);
                                    final unit = _unitForKey(
                                      _selectedKey ?? '',
                                    );
                                    if (d == null) return '— $unit';
                                    if (_selectedKey == 'rpm') {
                                      return '${d.toInt()} $unit';
                                    }
                                    return '${d.toStringAsFixed(1)} $unit';
                                  }(),
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: _stopChart,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _history.isEmpty
                                ? const Center(
                                    child: Text('Waiting for data...'),
                                  )
                                : _SimpleLineChart(
                                    key: ValueKey<int>(_chartTick),
                                    data: List<double>.from(_history),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

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
                final key = e['key'] as String;
                final val = model.values[key];
                debugPrint('LIVE TILE: ${e['label']}: $val');
                return OBDValueTile(
                  e['label']!,
                  val,
                  onTap: () => _startChart(key, model),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    super.dispose();
  }

  void _startChart(String key, OBDModel model) {
    if (_selectedKey == key) return;
    _stopChart();
    _selectedKey = key;
    _history = [];
    // seed with current value if present
    final v = model.values[key];
    final asDouble = _toDouble(v);
    if (asDouble != null) _history.add(asDouble);
    // start sampling at 1Hz
    _historyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final val = model.values[key];
      final d = _toDouble(val);
      if (d != null) {
        setState(() {
          _history.add(d);
          if (_history.length > _historyLength) _history.removeAt(0);
          _chartTick++;
        });
      }
    });
  }

  void _stopChart() {
    _historyTimer?.cancel();
    _historyTimer = null;
    setState(() {
      _selectedKey = null;
      _history = [];
    });
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString();
    return double.tryParse(s);
  }

  String _unitForKey(String key) {
    switch (key) {
      case 'rpm':
        return 'rpm';
      case 'speed_kmh':
        return 'km/h';
      case 'coolant_c':
      case 'intake_temp_c':
        return '°C';
      case 'throttle_%':
      case 'engine_load_%':
      case 'fuel_%':
        return '%';
      case 'maf_gps':
        return 'g/s';
      case 'fuel_pressure_kpa':
        return 'kPa';
      case 'battery_v':
        return 'V';
      default:
        return '';
    }
  }
}

class _SimpleLineChart extends StatelessWidget {
  final List<double> data;

  const _SimpleLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomPaint(painter: _LineChartPainter(data), size: Size.infinite),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // draw horizontal grid lines
    for (int i = 0; i < 4; i++) {
      final dy = size.height * (i / 4);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    if (data.isEmpty) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final minV = data.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1));
      final y = size.height - ((data[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // draw area fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.withOpacity(0.2), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // draw stroke
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
