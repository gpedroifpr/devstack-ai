import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreference extends ValueNotifier<ThemeMode> {
  ThemePreference() : super(ThemeMode.dark);
  static final instance = ThemePreference();
  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      'appearance',
    );
    value = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> select(ThemeMode mode) async {
    final stored = await (await SharedPreferences.getInstance()).setString(
      'appearance',
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    if (!stored) throw StateError('Não foi possível guardar a aparência.');
    value = mode;
  }
}

class AppPalette {
  static Color color(BuildContext context, Color original) =>
      resolve(Theme.of(context).brightness, original);

  static Color resolve(Brightness brightness, Color original) {
    if (brightness == Brightness.dark) return original;
    final value = original.toARGB32();
    final rgb = value & 0xffffff;
    final alpha = (value >> 24) / 255;
    Color? replacement;
    if (rgb == 0xffffff) replacement = const Color(0xFF172329);
    if (rgb == 0x000000) replacement = Colors.white;
    const surfaces = {
      0x0B1215: 0xFFF3F6F7,
      0x162126: 0xFFFFFFFF,
      0x10191D: 0xFFFFFFFF,
      0x10181C: 0xFFFFFFFF,
      0x0F171A: 0xFFEDF2F4,
      0x091013: 0xFFE8EFF1,
      0x0D171B: 0xFFEBF1F3,
      0x101A1F: 0xFFEDF2F4,
      0x101A1E: 0xFFEDF2F4,
      0x0A1114: 0xFFF5F8F9,
      0x0C1417: 0xFFEDF2F4,
      0x1D3035: 0xFFDCECEF,
      0x4EE2EC: 0xFF007B85,
      0x43DDE7: 0xFF007B85,
      0x70E6C6: 0xFF16684E,
    };
    if (surfaces.containsKey(rgb)) replacement = Color(surfaces[rgb]!);
    final r = (rgb >> 16) & 255;
    final g = (rgb >> 8) & 255;
    final b = rgb & 255;
    if (r == g && g == b && r != 0 && r != 255) {
      replacement = Color(r >= 200 ? 0xFF34454D : 0xFF596B74);
    }
    if (original == Colors.greenAccent ||
        original == Colors.greenAccent.shade100) {
      replacement = const Color(0xFF14734F);
    }
    if (original == Colors.orangeAccent ||
        original == Colors.amber ||
        original == Colors.orange) {
      replacement = const Color(0xFF966000);
    }
    if (original == Colors.redAccent) replacement = const Color(0xFFB82B40);
    return replacement?.withValues(alpha: alpha) ?? original;
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF007B85),
    brightness: brightness,
    primary: dark ? const Color(0xFF4EE2EC) : const Color(0xFF007B85),
    onPrimary: dark ? const Color(0xFF07181B) : Colors.white,
    surface: dark ? const Color(0xFF162126) : Colors.white,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0B1215)
        : const Color(0xFFF3F6F7),
    dividerColor: scheme.onSurface.withValues(alpha: .10),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF0F171A) : const Color(0xFFEDF2F4),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFDFEAED) : const Color(0xFF24373D),
      contentTextStyle: TextStyle(
        color: dark ? const Color(0xFF172329) : Colors.white,
      ),
    ),
  );
}
