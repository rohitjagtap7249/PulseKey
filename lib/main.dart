import 'package:flutter/material.dart';

import 'common.dart';
import 'timer_tab.dart';

void main() {
  runApp(const TimerApp());
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timer',
      debugShowCheckedModeBanner: false,
      theme: pkTheme(),
      home: const Scaffold(
        body: SafeArea(child: TimerTab()),
      ),
    );
  }
}
