import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zing_sdk_initializer/zing_sdk_initializer.dart';

const _apiKeyIos = 'yVbJzsVP.33rljbAHo9zm4zbyeOvc0dDV3bSSgDxf';
const _apiKeyAndroid = 'BFmIaLAC.7ACCWtEDJjxX5OxiYftMVOd0zHIW580S';

/// SDK setup used both on app startup (foreground) and in the headless background
/// isolate (Health Connect background sync). Must be a top-level function annotated
/// with `@pragma('vm:entry-point')` so it survives tree-shaking and can be looked up
/// by the native side in a fresh isolate.
@pragma('vm:entry-point')
Future<void> zingSdkSetup() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZingSdk.instance.init(
    configuration: const SdkConfiguration(
      coachesAvailability: CoachesAvailability.userGenderBased,
      genderAvailability: GenderAvailability.binary,
      healthBackgroundSync: true,
    ),
    theme: const SdkTheme(
      colors: SdkColors(
        brandPrimary: Color(0xFFF2001F),
        brandSecondary: Color(0xFF980052),
      ),
      cornersRounding: SdkCornerRounding(
        button: SdkRadius.value(0),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await zingSdkSetup();
    // Register the same setup so the native side can run it in a headless isolate
    // when the process is started in the background (alarm / reboot) for HC sync.
    await ZingSdk.instance.registerBackgroundSetup(zingSdkSetup);
  } on PlatformException catch (error, stackTrace) {
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zing SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TabBarPage(),
    );
  }
}

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});

  @override
  State<TabBarPage> createState() => _TabBarPageState();
}

class _TabBarPageState extends State<TabBarPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomePage(),
          StreamBuilder<SdkAuthState>(
            stream: ZingSdk.instance.authState,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state is! SdkAuthStateAuthenticated) {
                return const Center(
                  child: Text('Log in on the SDK tab to see the program.'),
                );
              }
              return ZingProgramView(key: ValueKey(state.userId));
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: SizedBox.shrink(), label: 'SDK'),
          NavigationDestination(icon: SizedBox.shrink(), label: 'Program'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _sdk = ZingSdk.instance;
  String? _error;
  SdkAuthState? _authState;
  StreamSubscription<SdkAuthState>? _authStateSub;
  String? _partnerUserId;

  static const _routes = <(String, StartingRoute)>[
    ('Home', HomeRoute()),
    ('Custom Workout', CustomWorkoutRoute()),
    ('AI Assistant', AiAssistantRoute()),
    ('Workout Plan Details', WorkoutPlanDetailsRoute()),
    ('Full Schedule', FullScheduleRoute()),
    ('Profile Settings', ProfileSettingsRoute()),
    ('Body Scan', BodyScanRoute()),
    ('Flexibility Test', FlexibilityTestRoute()),
    ('Fitness Test', FitnessTestRoute())
  ];

  @override
  void initState() {
    super.initState();
    _authStateSub = _sdk.authState.listen(
      (state) => setState(() => _authState = state),
      onError: (Object error) => setState(() => _error = error.toString()),
    );
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  Future<void> _loginOrLogout() async {
    setState(() => _error = null);
    try {
      final state = _authState;
      if (state is SdkAuthStateAuthenticated) {
        await _sdk.logout();
      } else if (state is! SdkAuthStateInProgress) {
        await _sdk.login(
          SdkAuthentication.apiKey(
            ios: _apiKeyIos,
            android: _apiKeyAndroid,
            partnerUserId: _partnerUserId,
          ),
        );
      }
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _setProfileParams() async {
    setState(() => _error = null);
    try {
      await _sdk.setProfileParams(
        const ProfileParams(
          name: 'Username',
          gender: UserGender.male,
          height: 178.9,
          weight: 67.8,
          age: 23,
          measurementSystem: MeasurementSystem.metric,
        ),
      );
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _showSetPartnerIdDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SetPartnerIdDialog(initialValue: _partnerUserId),
    );

    if (result == null || !mounted) return;
    setState(() {
      _partnerUserId = result.trim().isEmpty ? null : result.trim();
    });
  }

  Future<void> _openScreen(StartingRoute route) async {
    setState(() => _error = null);
    try {
      await _sdk.openScreen(route);
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zing SDK Example')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _authState is SdkAuthStateInProgress
                    ? null
                    : _loginOrLogout,
                child: Text(
                  switch (_authState) {
                    SdkAuthStateAuthenticated() => 'Logout',
                    SdkAuthStateInProgress() => 'In Progress...',
                    _ => 'Login',
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.tonal(
                onPressed: _authState is SdkAuthStateAuthenticated
                    ? _setProfileParams
                    : null,
                child: const Text('Set Profile Params'),
              ),
            ),
            if (_authState is SdkAuthStateLoggedOut) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: _showSetPartnerIdDialog,
                  child: Text(
                    _partnerUserId == null
                        ? 'Set Partner ID'
                        : 'Partner ID: $_partnerUserId',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Auth state: ${switch (_authState) {
                  SdkAuthStateAuthenticated() => 'Authenticated',
                  SdkAuthStateInProgress() => 'In progress',
                  SdkAuthStateLoggedOut() => 'Logged out',
                  null => 'Unknown',
                }}',
              ),
            ),
            if (_authState case SdkAuthStateAuthenticated(:final userId)) ...[
              const SizedBox(height: 4),
              Center(
                child: InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: userId));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied')),
                    );
                  },
                  child: Text('User ID: $userId'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 48),
            for (final (label, route) in _routes) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () => _openScreen(route),
                  child: Text(label),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetPartnerIdDialog extends StatefulWidget {
  const _SetPartnerIdDialog({required this.initialValue});

  final String? initialValue;

  @override
  State<_SetPartnerIdDialog> createState() => _SetPartnerIdDialogState();
}

class _SetPartnerIdDialogState extends State<_SetPartnerIdDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Partner ID'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'partnerUserId'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Setup'),
        ),
      ],
    );
  }
}
