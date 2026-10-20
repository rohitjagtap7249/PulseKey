import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';

class StopwatchTab extends StatefulWidget {
  const StopwatchTab({super.key, required this.active});

  final bool active;

  @override
  State<StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<StopwatchTab> {
  bool _running = false;
  int _startEpoch = 0;
  int _accum = 0;
  List<int> _laps = <int>[];
  Timer? _ticker;

  int get _elapsed => _running
      ? _accum + (DateTime.now().millisecondsSinceEpoch - _startEpoch)
      : _accum;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StopwatchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final String? raw = await storeGet('sw.state');
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _running = m['running'] == true;
        _startEpoch = (m['start'] as num).toInt();
        _accum = (m['accum'] as num).toInt();
        _laps = (m['laps'] as List<dynamic>)
            .map((dynamic e) => (e as num).toInt())
            .toList();
      });
      _syncTicker();
    } catch (_) {
      // ignore bad saved data
    }
  }

  void _save() {
    storeSet(
      'sw.state',
      jsonEncode(<String, dynamic>{
        'running': _running,
        'start': _startEpoch,
        'accum': _accum,
        'laps': _laps,
      }),
    );
  }

  void _syncTicker() {
    if (widget.active && _running) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _toggle() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      if (_running) {
        _accum += now - _startEpoch;
        _running = false;
      } else {
        _startEpoch = now;
        _running = true;
      }
    });
    _syncTicker();
    _save();
  }

  void _lap() {
    if (!_running) return;
    setState(() => _laps.add(_elapsed));
    _save();
  }

  void _reset() {
    setState(() {
      _running = false;
      _accum = 0;
      _laps = <int>[];
    });
    _syncTicker();
    _save();
  }

  String _fmt(int ms) {
    final int cs = (ms ~/ 10) % 100;
    final int total = ms ~/ 1000;
    final int s = total % 60;
    final int m = (total ~/ 60) % 60;
    final int h = total ~/ 3600;
    if (h > 0) return '$h:${two(m)}:${two(s)}.${two(cs)}';
    return '${two(m)}:${two(s)}.${two(cs)}';
  }

  List<int> get _lapTimes {
    final List<int> out = <int>[];
    int prev = 0;
    for (final int c in _laps) {
      out.add(c - prev);
      prev = c;
    }
    return out;
  }

  void _copy(List<int> lapTimes) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < lapTimes.length; i++) {
      b.writeln('Lap ${i + 1}  ${_fmt(lapTimes[i])}  ${_fmt(_laps[i])}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lap times copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int ms = _elapsed;
    final List<int> lapTimes = _lapTimes;
    final bool many = lapTimes.length >= 3;
    final int best = many ? lapTimes.reduce(math.min) : -1;
    final int worst = many ? lapTimes.reduce(math.max) : -1;
    final int avg = lapTimes.isEmpty
        ? 0
        : lapTimes.reduce((int a, int b) => a + b) ~/ lapTimes.length;
    final bool showLapLabel = _running || _laps.isNotEmpty;

    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Stopwatch',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Pk.blue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(child: CustomPaint(painter: _DialPainter(ms))),
              Align(
                alignment: const Alignment(0, 0.42),
                child: SizedBox(
                  width: 130,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _fmt(ms),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: Pk.blue,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.72),
                child: Text(
                  showLapLabel ? 'Lap ${_laps.length + 1}' : '',
                  style: const TextStyle(fontSize: 11, color: Pk.muted),
                ),
              ),
            ],
          ),
        ),
        if (lapTimes.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Average ${_fmt(avg)}',
                  style: const TextStyle(fontSize: 13, color: Pk.muted),
                ),
                TextButton(
                  onPressed: () => _copy(lapTimes),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: lapTimes.length,
            itemBuilder: (BuildContext ctx, int i) {
              final int idx = lapTimes.length - 1 - i;
              final bool isBest = many && lapTimes[idx] == best;
              final bool isWorst = many && lapTimes[idx] == worst;
              final Color lapColor =
                  isBest ? Pk.blue : (isWorst ? Pk.red : Pk.text);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Pk.line, width: 0.5),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Lap ${idx + 1}',
                        style: const TextStyle(fontSize: 14, color: Pk.muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _fmt(lapTimes[idx]) +
                            (isBest ? '  Best' : (isWorst ? '  Worst' : '')),
                        style: TextStyle(fontSize: 14, color: lapColor),
                      ),
                    ),
                    Text(
                      _fmt(_laps[idx]),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Pk.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RoundButton(
                icon: Icons.flag_outlined,
                tooltip: 'Lap',
                bg: Colors.white,
                fg: Pk.blue,
                size: 56,
                onTap: _running ? _lap : null,
              ),
              const SizedBox(width: 28),
              RoundButton(
                icon: _running ? Icons.pause : Icons.play_arrow,
                tooltip: _running ? 'Pause' : 'Start',
                size: 68,
                onTap: _toggle,
              ),
              const SizedBox(width: 28),
              RoundButton(
                icon: Icons.refresh,
                tooltip: 'Reset',
                bg: Colors.white,
                fg: Pk.blue,
                size: 56,
                onTap: (!_running && ms > 0) ? _reset : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.ms);

  final int ms;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    canvas.drawCircle(c, r - 2, Paint()..color = Pk.disc);
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..color = const Color(0xFFE6E8EC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Paint minor = Paint()
      ..color = const Color(0xFFB8BCC4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final Paint major = Paint()
      ..color = Pk.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 60; i++) {
      final double a = -math.pi / 2 + i * 2 * math.pi / 60;
      final Offset d = Offset(math.cos(a), math.sin(a));
      final bool big = i % 5 == 0;
      canvas.drawLine(
        c + d * (r - (big ? 22 : 16)),
        c + d * (r - 8),
        big ? major : minor,
      );
    }
    const List<String> nums = <String>['60', '15', '30', '45'];
    for (int k = 0; k < 4; k++) {
      final double a = -math.pi / 2 + k * math.pi / 2;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: nums[k],
          style: const TextStyle(fontSize: 12, color: Pk.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * (r - 38);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    final double sec = (ms % 60000) / 1000.0;
    final double na = -math.pi / 2 + sec / 60 * 2 * math.pi;
    final Offset nd = Offset(math.cos(na), math.sin(na));
    final Paint needle = Paint()
      ..color = Pk.red
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - nd * 16, c + nd * (r - 24), needle);
    canvas.drawCircle(c, 6, Paint()..color = Pk.red);
    canvas.drawCircle(c, 2.4, Paint()..color = Pk.disc);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.ms != ms;
}
