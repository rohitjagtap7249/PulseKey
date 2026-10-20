import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Pk {
  static const Color blue = Color(0xFF2567FF);
  static const Color red = Color(0xFFEA3B2E);
  static const Color bg = Color(0xFFF0F1F3);
  static const Color text = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF8A8D93);
  static const Color faded = Color(0xFFC9CCD2);
  static const Color disc = Color(0xFFF5F6F8);
  static const Color line = Color(0xFFDADCE0);
}

const MethodChannel kChannel = MethodChannel('pulsekey/timer');

Future<String?> storeGet(String key) async {
  try {
    return await kChannel.invokeMethod<String>(
      'storeGet',
      <String, dynamic>{'key': key},
    );
  } on Exception catch (_) {
    return null;
  }
}

Future<void> storeSet(String key, String value) async {
  try {
    await kChannel.invokeMethod<void>(
      'storeSet',
      <String, dynamic>{'key': key, 'value': value},
    );
  } on Exception catch (_) {
    // ignore
  }
}

String two(int v) => v.toString().padLeft(2, '0');

String clockText(int ms) {
  final int total = (ms + 999) ~/ 1000;
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  final int s = total % 60;
  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

ThemeData pkTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: Pk.blue,
    brightness: Brightness.light,
  ).copyWith(primary: Pk.blue);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pk.bg,
  );
}

class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.bg = Pk.red,
    this.fg = Colors.white,
    this.size = 60,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: fg, size: size * 0.46),
            ),
          ),
        ),
      ),
    );
  }
}
