import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';

class _Preset {
  _Preset(this.name, this.seconds);

  String name;
  final int seconds;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'name': name, 'seconds': seconds};

  static _Preset fromJson(Map<String, dynamic> m) =>
      _Preset(m['name'] as String, (m['seconds'] as num).toInt());
}

class TimerTab extends StatefulWidget {
  const TimerTab({super.key});

  @override
  State<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<TimerTab> with WidgetsBindingObserver {
  final FixedExtentScrollController _hc = FixedExtentScrollController();
  final FixedExtentScrollController _mc =
      FixedExtentScrollController(initialItem: 10);
  final FixedExtentScrollController _sc = FixedExtentScrollController();
  int _h = 0;
  int _m = 10;
  int _s = 0;

  Timer? _poll;
  String _state = 'idle';
  int _durationMs = 0;
  int _remainingMs = 0;
  List<String> _outputs = <String>[];
  List<String> _log = <String>[];
  bool _notifOk = true;
  bool _fullScreenOk = true;
  String _label = 'Timer';
  List<_Preset> _presets = <_Preset>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSaved();
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
    _hc.dispose();
    _mc.dispose();
    _sc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _call('refresh');
    }
  }

  Future<void> _loadSaved() async {
    final String? p = await storeGet('timer.presets');
    final String? lab = await storeGet('timer.label');
    final String? last = await storeGet('timer.last');
    if (!mounted) return;
    List<_Preset> list = <_Preset>[
      _Preset('Focus', 1500),
      _Preset('Short break', 300),
      _Preset('Deep work', 3600),
    ];
    if (p != null && p.isNotEmpty) {
      try {
        list = (jsonDecode(p) as List<dynamic>)
            .map((dynamic e) => _Preset.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // keep defaults
      }
    }
    setState(() {
      _presets = list;
      if (lab != null && lab.isNotEmpty) _label = lab;
    });
    final int? sec = int.tryParse(last ?? '');
    if (sec != null && sec > 0) _setWheels(sec);
  }

  void _setWheels(int sec) {
    final int h = (sec ~/ 3600) % 24;
    final int m = (sec ~/ 60) % 60;
    final int s = sec % 60;
    setState(() {
      _h = h;
      _m = m;
      _s = s;
    });
    if (_hc.hasClients) _hc.jumpToItem(h);
    if (_mc.hasClients) _mc.jumpToItem(m);
    if (_sc.hasClients) _sc.jumpToItem(s);
  }

  Future<void> _refresh() async {
    try {
      final Map<String, dynamic>? s =
          await kChannel.invokeMapMethod<String, dynamic>('state');
      if (s == null || !mounted) return;
      setState(() {
        _state = s['state'] as String;
        _durationMs = (s['durationMs'] as num).toInt();
        _remainingMs = (s['remainingMs'] as num).toInt();
        _outputs = (s['outputs'] as List<dynamic>).cast<String>();
        _notifOk = s['notifOk'] == true;
        _fullScreenOk = s['fullScreenOk'] == true;
        _log = (s['log'] as List<dynamic>).cast<String>();
      });
    } on Exception catch (_) {
      // Native side not available (for example in tests).
    }
  }

  Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      await kChannel.invokeMethod<void>(method, args);
    } on Exception catch (_) {
      // ignore
    }
    await _refresh();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startTimer(int seconds, String label) async {
    if (seconds < 1) {
      _snack('Pick a time first');
      return;
    }
    final int secs = seconds > 86400 ? 86400 : seconds;
    setState(() => _label = label);
    await storeSet('timer.label', label);
    await storeSet('timer.last', '$secs');
    await _call('start', <String, dynamic>{'durationMs': secs * 1000});
  }

  Future<void> _savePresets() async {
    await storeSet(
      'timer.presets',
      jsonEncode(_presets.map((_Preset p) => p.toJson()).toList()),
    );
  }

  Future<void> _addPreset() async {
    final int sec = _h * 3600 + _m * 60 + _s;
    if (sec < 1) {
      _snack('Pick a time first');
      return;
    }
    final TextEditingController c = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Save this timer'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name, for example Focus'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() => _presets.add(_Preset(name.isEmpty ? 'Timer' : name, sec)));
    await _savePresets();
  }

  Future<void> _editPreset(int index) async {
    final TextEditingController c =
        TextEditingController(text: _presets[index].name);
    final String? res = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Edit quick timer'),
        content: TextField(controller: c, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save|${c.text.trim()}'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      if (res == 'delete') {
        _presets.removeAt(index);
      } else if (res.startsWith('save|')) {
        final String n = res.substring(5);
        if (n.isNotEmpty) _presets[index].name = n;
      }
    });
    await _savePresets();
  }

  void _showLog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Event log'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              _log.isEmpty ? 'No events yet' : _log.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _call('clearLog');
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _hms(int sec) =>
      '${two(sec ~/ 3600)}:${two((sec ~/ 60) % 60)}:${two(sec % 60)}';

  String _ringTime() {
    final DateTime end =
        DateTime.now().add(Duration(milliseconds: _remainingMs));
    final int h12 = end.hour % 12 == 0 ? 12 : end.hour % 12;
    return '${two(h12)}:${two(end.minute)} ${end.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _neckbandChip() {
    String name = 'No neckband';
    bool on = false;
    for (final String o in _outputs) {
      if (o.startsWith('Bluetooth A2DP')) {
        name = o.substring(o.indexOf(':') + 2);
        on = true;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bluetooth, size: 16, color: on ? Pk.blue : Pk.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Pk.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _neckbandChip(),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Pk.text),
            onSelected: (String v) {
              if (v == 'log') {
                _showLog();
              } else {
                _call('openSettings', <String, dynamic>{'kind': 'app'});
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'log',
                child: Text('Event log'),
              ),
              const PopupMenuItem<String>(
                value: 'app',
                child: Text('Battery and app settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _warning(String message, String label, String kind) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style: const TextStyle(fontSize: 13, color: Pk.text),
              ),
              TextButton(
                onPressed: () =>
                    _call('openSettings', <String, dynamic>{'kind': kind}),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _warnings() {
    final List<Widget> out = <Widget>[];
    if (!_notifOk) {
      out.add(_warning(
        'Notifications are blocked. You will not see the running timer or the Time\'s up alert.',
        'Open notification settings',
        'notifications',
      ));
    }
    if (!_fullScreenOk) {
      out.add(_warning(
        'Full-screen alerts are not allowed, so Time\'s up may not open over the lock screen.',
        'Allow full-screen alerts',
        'fullscreen',
      ));
    }
    return out;
  }

  Widget _idleBody() {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        SizedBox(
          height: 156,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Wheel(
                    count: 24,
                    value: _h,
                    controller: _hc,
                    onChanged: (int v) => setState(() => _h = v),
                  ),
                ),
                const _Colon(),
                Expanded(
                  child: _Wheel(
                    count: 60,
                    value: _m,
                    controller: _mc,
                    onChanged: (int v) => setState(() => _m = v),
                  ),
                ),
                const _Colon(),
                Expanded(
                  child: _Wheel(
                    count: 60,
                    value: _s,
                    controller: _sc,
                    onChanged: (int v) => setState(() => _s = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Frequently used timers',
                style: TextStyle(fontSize: 15, color: Pk.text),
              ),
              InkWell(
                onTap: _addPreset,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Add',
                    style: TextStyle(fontSize: 15, color: Pk.red),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
            itemCount: _presets.length,
            itemBuilder: (BuildContext ctx, int i) => _presetCard(i),
          ),
        ),
      ],
    );
  }

  Widget _presetCard(int i) {
    final _Preset p = _presets[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _startTimer(p.seconds, p.name),
          onLongPress: () => _editPreset(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  p.name,
                  style: const TextStyle(fontSize: 15, color: Pk.text),
                ),
                Text(
                  _hms(p.seconds),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Pk.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring() {
    final bool ringing = _state == 'ringing';
    final bool paused = _state == 'paused';
    final bool counting = _state == 'running' || paused;
    final double progress = counting && _durationMs > 0
        ? (_remainingMs / _durationMs).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final String sub =
        ringing ? 'Time\'s up' : (paused ? 'Paused' : 'Rings at ${_ringTime()}');
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Pk.disc,
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _RingPainter(progress))),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _label,
                style: const TextStyle(fontSize: 14, color: Pk.muted),
              ),
              Text(
                clockText(ringing ? 0 : _remainingMs),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  color: Pk.blue,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 12, color: Pk.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeBody() {
    final bool ringing = _state == 'ringing';
    final bool paused = _state == 'paused';
    return Column(
      children: <Widget>[
        const SizedBox(height: 16),
        _ring(),
        const SizedBox(height: 22),
        if (!ringing)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _call('addTime', <String, dynamic>{'ms': 60000}),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E6EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.add, size: 16, color: Color(0xFF6B6E75)),
                  SizedBox(width: 6),
                  Text(
                    '1 min',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6E75)),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (ringing)
              RoundButton(
                icon: Icons.replay,
                tooltip: 'Repeat',
                bg: Pk.blue,
                size: 64,
                onTap: () => _call('restart'),
              )
            else
              RoundButton(
                icon: paused ? Icons.play_arrow : Icons.pause,
                tooltip: paused ? 'Resume' : 'Pause',
                bg: Pk.blue,
                size: 64,
                onTap: () => _call(paused ? 'resume' : 'pause'),
              ),
            const SizedBox(width: 40),
            RoundButton(
              icon: Icons.close,
              tooltip: 'Stop',
              bg: Colors.white,
              fg: Pk.blue,
              size: 64,
              onTap: () => _call('stop'),
            ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool idle = _state == 'idle';
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Column(
            children: <Widget>[
              _header(),
              ..._warnings(),
              Expanded(child: idle ? _idleBody() : _activeBody()),
            ],
          ),
        ),
        if (idle)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: RoundButton(
                icon: Icons.play_arrow,
                tooltip: 'Start timer',
                size: 64,
                onTap: () => _startTimer(_h * 3600 + _m * 60 + _s, 'Timer'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      child: Center(
        child: Text(
          ':',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: Pk.blue,
          ),
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.count,
    required this.value,
    required this.controller,
    required this.onChanged,
  });

  final int count;
  final int value;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 52,
      diameterRatio: 4,
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (int i) => onChanged(i % count),
      childDelegate: ListWheelChildLoopingListDelegate(
        children: List<Widget>.generate(
          count,
          (int i) => Center(
            child: Text(
              two(i),
              style: TextStyle(
                fontSize: i == value ? 42 : 28,
                fontWeight: i == value ? FontWeight.w500 : FontWeight.w300,
                color: i == value ? Pk.blue : Pk.faded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = size.width / 2 - 14;
    const int n = 120;
    final int lit = (progress * n).ceil();
    final Paint on = Paint()
      ..color = Pk.blue
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Paint off = Paint()
      ..color = const Color(0xFFCFD2D8)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < n; i++) {
      final double a = -math.pi / 2 + i * 2 * math.pi / n;
      final Offset d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (outer - 12), c + d * outer, i < lit ? on : off);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
