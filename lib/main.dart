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
  static const MethodChannel _channel = MethodChannel('pulsekey/diag');

  Timer? _timer;
  bool _running = false;
  List<String> _log = <String>[];
  List<String> _outputs = <String>[];

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final Map<String, dynamic>? state =
          await _channel.invokeMapMethod<String, dynamic>('state');
      if (state == null || !mounted) return;
      setState(() {
        _running = state['running'] == true;
        _log = (state['log'] as List<dynamic>).cast<String>().reversed.toList();
        _outputs = (state['outputs'] as List<dynamic>).cast<String>();
      });
    } on Exception catch (_) {
      // Native side not available (for example in tests).
    }
  }

  Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on Exception catch (_) {
      // ignore
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PulseKey', style: text.headlineMedium),
              const Text('Button diagnostic (Stage 2)'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _running
                            ? 'Capture ON: PulseKey holds the media session'
                            : 'Capture OFF: media buttons behave normally',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _outputs.isEmpty
                            ? 'Audio outputs: none found'
                            : 'Audio outputs:\n${_outputs.join('\n')}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _call(_running ? 'stop' : 'start'),
                      child: Text(_running ? 'Stop capture' : 'Start capture'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _call('clear'),
                    child: const Text('Clear log'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (BuildContext context, int i) => Text(
                    _log[i],
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
    );
  }
}
