import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PulseKeyApp());
}

class PulseKeyApp extends StatelessWidget {
  const PulseKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulseKey',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00E5C3),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('pulsekey/timer');
  static const List<int> _presets = <int>[5, 10, 25, 45, 60];

  final TextEditingController _minutes = TextEditingController(text: '10');
  Timer? _poll;
  String _state = 'idle';
  int _durationMs = 0;
  int _remainingMs = 0;
  List<String> _outputs = <String>[];
  List<String> _log = <String>[];
  bool _notifOk = true;
  bool _fullScreenOk = true;
  bool _batteryOk = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _minutes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _call('refresh');
    }
  }

  Future<void> _refresh() async {
    try {
      final Map<String, dynamic>? s =
          await _channel.invokeMapMethod<String, dynamic>('state');
      if (s == null || !mounted) return;
      setState(() {
        _state = s['state'] as String;
        _durationMs = (s['durationMs'] as num).toInt();
        _remainingMs = (s['remainingMs'] as num).toInt();
        _outputs = (s['outputs'] as List<dynamic>).cast<String>();
        _notifOk = s['notifOk'] == true;
        _fullScreenOk = s['fullScreenOk'] == true;
        _batteryOk = s['batteryOk'] == true;
        _log = (s['log'] as List<dynamic>).cast<String>();
      });
    } on Exception catch (_) {
      // Native side not available (for example in tests).
    }
  }

  Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Exception catch (_) {
      // ignore
    }
    await _refresh();
  }

  void _start() {
    final int? m = int.tryParse(_minutes.text);
    if (m == null || m < 1 || m > 1440) {
      setState(() => _error = 'Enter 1 to 1440 minutes');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    _call('start', <String, dynamic>{'durationMs': m * 60000});
  }

  String _clock(int ms) {
    final int total = (ms + 999) ~/ 1000;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String get _statusText {
    switch (_state) {
      case 'running':
        return 'Timer running';
      case 'paused':
        return 'Paused';
      case 'ringing':
        return "Time's up!";
      default:
        return 'Ready';
    }
  }

  String get _neckband {
    for (final String o in _outputs) {
      if (o.startsWith('Bluetooth A2DP')) {
        return o.substring(o.indexOf(':') + 2);
      }
    }
    return 'No neckband connected';
  }

  double get _progress {
    if (_state == 'running' || _state == 'paused') {
      if (_durationMs <= 0) return 0.0;
      return (_remainingMs / _durationMs).clamp(0.0, 1.0).toDouble();
    }
    return _state == 'ringing' ? 0.0 : 1.0;
  }

  Widget _warning(String message, String label, String kind) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () =>
                  _call('openSettings', <String, dynamic>{'kind': kind}),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final bool idle = _state == 'idle';
    final bool running = _state == 'running';
    final bool paused = _state == 'paused';
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (idle)
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          )
        else
          FilledButton.icon(
            onPressed: (running || paused)
                ? () => _call(running ? 'pause' : 'resume')
                : null,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            label: Text(paused ? 'Resume' : 'Pause'),
          ),
        FilledButton.tonalIcon(
          onPressed: idle ? null : () => _call('stop'),
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
        FilledButton.tonalIcon(
          onPressed: _durationMs > 0 ? () => _call('restart') : null,
          icon: const Icon(Icons.replay),
          label: const Text('Repeat'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool idle = _state == 'idle';
    final int shownMs =
        idle ? (int.tryParse(_minutes.text) ?? 0) * 60000 : _remainingMs;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: cs.primary),
                const SizedBox(width: 8),
                Text('PulseKey', style: text.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.bluetooth, size: 18),
                label: Text(_neckband),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 10,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _clock(shownMs),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_statusText, style: text.titleMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (idle) ...[
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final int p in _presets)
                    ChoiceChip(
                      label: Text('$p min'),
                      selected: _minutes.text == '$p',
                      onSelected: (_) => setState(() => _minutes.text = '$p'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Minutes (1 to 1440)',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _controls(),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _state == 'ringing'
                      ? 'Alarm ringing: use the pop-up or notification'
                      : 'Media buttons: normal (Spotify and neckband unchanged)',
                ),
              ),
            ),
            if (!_notifOk)
              _warning(
                'Notifications are blocked. You will not see the running '
                'timer or the Time\'s up alert.',
                'Open notification settings',
                'notifications',
              ),
            if (!_fullScreenOk)
              _warning(
                'Full-screen alerts are not allowed, so the Time\'s up screen '
                'may not open over the lock screen.',
                'Allow full-screen alerts',
                'fullscreen',
              ),
            if (!_batteryOk)
              _warning(
                'Tip: on OnePlus set Battery to "Allow background activity" '
                'or Unrestricted so the alarm is never delayed.',
                'Open app settings',
                'app',
              ),
            ExpansionTile(
              title: const Text('Event log'),
              children: [
                if (_log.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No events yet'),
                  )
                else
                  for (final String line in _log)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                TextButton(
                  onPressed: () => _call('clearLog'),
                  child: const Text('Clear log'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
