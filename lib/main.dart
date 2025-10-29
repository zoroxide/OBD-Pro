import 'package:flutter/material.dart';
import 'package:obd_reader/pages/account_page.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/settings_page.dart';
import 'pages/ai_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/onboarding_page.dart';

import 'models/obd_model.dart';
import 'core/bluetooth_service.dart';
import 'core/obd_service.dart';
import 'core/log_service.dart';
import 'pages/live_data_page.dart';
import 'pages/connect_page.dart';
import 'pages/fault_codes_page.dart';
import 'pages/advanced_debug_page.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('seen_onboarding') ?? false);

  runApp(
    MultiProvider(
      providers: [
        Provider<BluetoothService>(create: (_) => BluetoothService()),
        Provider(create: (_) => LogService()),
        ProxyProvider2<BluetoothService, LogService, OBDService>(
          update: (_, bt, log, __) => OBDService(bt, log),
        ),
        ChangeNotifierProxyProvider3<
          OBDService,
          BluetoothService,
          LogService,
          OBDModel
        >(
          create: (ctx) => OBDModel(
            Provider.of<OBDService>(ctx, listen: false),
            Provider.of<BluetoothService>(ctx, listen: false),
            Provider.of<LogService>(ctx, listen: false),
          ),
          update: (_, obd, bt, log, __) => OBDModel(obd, bt, log),
        ),
      ],
      child: MyApp(showOnboarding: showOnboarding),
    ),
  );
}

class _DrawerContent extends StatefulWidget {
  const _DrawerContent({Key? key}) : super(key: key);

  @override
  State<_DrawerContent> createState() => _DrawerContentState();
}

class _DrawerContentState extends State<_DrawerContent> {
  final int _tabIndex = 0;
  bool productionMode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Color.fromARGB(255, 77, 10, 60)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🔮 OBD Pro',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Debug'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvancedDebugPage()),
            );
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: _tabIndex == 0
                ? _buildSettingsTab(context)
                : _buildDebugTab(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildDebugTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text('Open advanced debugging tools and logs.'),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvancedDebugPage()),
            );
          },
          child: const Text('Open Debug'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBD Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: showOnboarding ? const OnboardingPage() : const HomeScaffold(),
    );
  }
}

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _index = 0;

  final _pages = const [LiveDataPage(), FaultCodesPage(), AIPage()];

  void _openConnect(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const ConnectPage()));
  }

  void _openAccount(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔮 OBD Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _openAccount(context),
            tooltip: 'Account',
          ),
        ],
      ),
      drawer: Drawer(child: _DrawerContent()),
      body: _pages[(_index >= 0 && _index < _pages.length) ? _index : 0],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _openConnect(context),
        child: const Icon(Icons.bluetooth, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i >= 0 && i < _pages.length) {
            setState(() => _index = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed, color: Colors.redAccent),
            label: 'Live Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem, color: Colors.amber),
            label: 'Faults',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome, color: Colors.deepPurple),
            label: 'AI Mechanic',
          ),
        ],
      ),
    );
  }
}
