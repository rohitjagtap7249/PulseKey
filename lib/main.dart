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

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _channel = MethodChannel('pulsekey/timer');

  final TextEditingController _minutes = TextEditingController(text: '10');
  Timer? _poll;
  String _state = 'idle';
  int _durationMs = 0;
  int _remainingMs = 0;
  List<String> _outputs = <String>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _minutes.dispose();
    super.dispose();
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
        return 'Time is up!';
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
    return 'not connected';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool idle = _state == 'idle';
    final bool running = _state == 'running';
    final bool paused = _state == 'paused';
    final int shownMs = idle ? (int.tryParse(_minutes.text) ?? 0) * 60000 : _remainingMs;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('PulseKey', style: text.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _minutes,
              enabled: idle,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Duration (minutes, 1 to 1440)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              child: Text(
                _clock(shownMs),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(_statusText, style: text.titleMedium)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: idle ? _start : null,
                  child: const Text('Start'),
                ),
                FilledButton.tonal(
                  onPressed: (running || paused)
                      ? () => _call(running ? 'pause' : 'resume')
                      : null,
                  child: Text(paused ? 'Resume' : 'Pause'),
                ),
                FilledButton.tonal(
                  onPressed: idle ? null : () => _call('stop'),
                  child: const Text('Stop'),
                ),
                FilledButton.tonal(
                  onPressed: _durationMs > 0 ? () => _call('restart') : null,
                  child: const Text('Repeat'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neckband: $_neckband'),
                    const SizedBox(height: 6),
                    Text(
                      _state == 'ringing'
                          ? 'Alarm ringing: use the pop-up or notification'
                          : 'Media buttons: normal (Spotify and neckband unchanged)',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
