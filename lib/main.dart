import 'package:flutter/material.dart';

import 'common.dart';
import 'stopwatch_tab.dart';
import 'timer_tab.dart';

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
      theme: pkTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            const AlarmPlaceholder(),
            StopwatchTab(active: _index == 1),
            const TimerTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onChanged: (int i) => setState(() => _index = i),
      ),
    );
  }
}

class AlarmPlaceholder extends StatelessWidget {
  const AlarmPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.alarm, size: 56, color: Pk.blue),
          SizedBox(height: 12),
          Text(
            'Alarms are coming in the next update',
            style: TextStyle(fontSize: 15, color: Pk.muted),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<IconData> icons = <IconData>[
      Icons.alarm,
      Icons.timer_outlined,
      Icons.hourglass_top,
    ];
    const List<String> labels = <String>['Alarm', 'Stopwatch', 'Timer'];
    return Material(
      color: const Color(0xFFFAFAFA),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Pk.line, width: 0.5)),
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onChanged(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            icons[i],
                            size: 24,
                            color: i == index ? Pk.blue : Pk.muted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: i == index ? Pk.blue : Pk.muted,
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
