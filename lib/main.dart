import 'dart:async';

import 'package:flutter/material.dart';

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
theme: ThemeData(
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF6750A4),
brightness: Brightness.dark,
),
useMaterial3: true,
),
home: const TimerPage(),
);
}
}

class TimerPage extends StatefulWidget {
const TimerPage({super.key});

@override
State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
final TextEditingController _minutesController =
TextEditingController(text: '10');

Timer? _ticker;

int _remainingSeconds = 600;
int _lastDuration = 600;

bool _isRunning = false;
bool _isPaused = false;
bool _hasStarted = false;

@override
void dispose() {
_ticker?.cancel();
_minutesController.dispose();
super.dispose();
}

String get _formattedTime {
final minutes = _remainingSeconds ~/ 60;
final seconds = _remainingSeconds % 60;

return '${minutes.toString().padLeft(2, '0')}:'
    '${seconds.toString().padLeft(2, '0')}';

}

void _startTimer() {
final minutes = int.tryParse(_minutesController.text.trim());

if (!_hasStarted && (minutes == null || minutes < 1 || minutes > 1440)) {
  _showMessage('Enter a duration between 1 and 1440 minutes.');
  return;
}

if (!_hasStarted) {
  _lastDuration = minutes! * 60;
  _remainingSeconds = _lastDuration;
}

_ticker?.cancel();

setState(() {
  _isRunning = true;
  _isPaused = false;
  _hasStarted = true;
});

_ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (!mounted) return;

  if (_remainingSeconds <= 1) {
    timer.cancel();

    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _isPaused = false;
    });

    _showMessage('Timer finished!');
    return;
  }

  setState(() {
    _remainingSeconds--;
  });
});

}

void _pauseTimer() {
if (!_isRunning) return;

_ticker?.cancel();

setState(() {
  _isRunning = false;
  _isPaused = true;
});

}

void _resumeTimer() {
if (!_isPaused) return;
_startTimer();
}

void _stopTimer() {
_ticker?.cancel();

setState(() {
  _remainingSeconds = _lastDuration;
  _isRunning = false;
  _isPaused = false;
  _hasStarted = false;
});

}

void _repeatTimer() {
_ticker?.cancel();

setState(() {
  _remainingSeconds = _lastDuration;
  _isRunning = false;
  _isPaused = false;
  _hasStarted = false;
});

_startTimer();

}

void _showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(message)),
);

}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'PulseKey',
style: TextStyle(fontWeight: FontWeight.bold),
),
centerTitle: true,
),
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(
Icons.headphones_rounded,
size: 72,
),
const SizedBox(height: 12),
const Text(
'Your buttons. Your control.',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 18),
),
const SizedBox(height: 40),
TextField(
controller: _minutesController,
keyboardType: TextInputType.number,
enabled: !_isRunning && !_isPaused,
textAlign: TextAlign.center,
decoration: const InputDecoration(
labelText: 'Timer duration',
suffixText: 'minutes',
border: OutlineInputBorder(),
),
),
const SizedBox(height: 28),
Text(
_formattedTime,
style: const TextStyle(
fontSize: 64,
fontWeight: FontWeight.bold,
fontFeatures: [],
),
),
const SizedBox(height: 12),
Text(
_isRunning
? 'Timer running'
: _isPaused
? 'Timer paused'
: 'Timer stopped',
style: Theme.of(context).textTheme.titleMedium,
),
const SizedBox(height: 32),
Wrap(
alignment: WrapAlignment.center,
spacing: 12,
runSpacing: 12,
children: [
FilledButton.icon(
onPressed: _isRunning ? null : _startTimer,
icon: const Icon(Icons.play_arrow),
label: Text(_isPaused ? 'Resume' : 'Start'),
),
OutlinedButton.icon(
onPressed: _isRunning ? _pauseTimer : null,
icon: const Icon(Icons.pause),
label: const Text('Pause'),
),
OutlinedButton.icon(
onPressed: _hasStarted ? _stopTimer : null,
icon: const Icon(Icons.stop),
label: const Text('Stop'),
),
OutlinedButton.icon(
onPressed: _hasStarted ? _repeatTimer : null,
icon: const Icon(Icons.repeat),
label: const Text('Repeat'),
),
],
),
const SizedBox(height: 32),
const Card(
child: Padding(
padding: EdgeInsets.all(16),
child: Row(
children: [
Icon(Icons.bluetooth_audio, size: 32),
SizedBox(width: 12),
Expanded(
child: Text(
'Neckband controls will be integrated '
'after the initial APK build.',
),
),
],
),
),
),
],
),
),
),
),
);
}
}
