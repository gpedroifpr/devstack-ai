import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/appearance_button.dart';
import 'package:flutter_application_1/widgets/post_editor_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemePreference.instance.value = ThemeMode.dark;
  });

  test('dark is the default; selected theme survives reload', () async {
    final preference = ThemePreference();
    await preference.load();
    expect(preference.value, ThemeMode.dark);
    await preference.select(ThemeMode.light);
    final restored = ThemePreference();
    await restored.load();
    expect(restored.value, ThemeMode.light);
    await restored.select(ThemeMode.dark);
    await preference.load();
    expect(preference.value, ThemeMode.dark);
    preference.dispose();
    restored.dispose();
  });

  test('both themes have readable text and primary buttons', () {
    double contrast(Color a, Color b) {
      final l = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (l.last + .05) / (l.first + .05);
    }

    for (final brightness in Brightness.values) {
      final theme = buildAppTheme(brightness);
      expect(
        contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      final text = AppPalette.resolve(brightness, Colors.white);
      final surface = AppPalette.resolve(brightness, const Color(0xFF10191D));
      expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
    }
    expect(
      AppPalette.resolve(Brightness.dark, const Color(0xFF162126)),
      const Color(0xFF162126),
    );
  });

  testWidgets('theme toggle preserves draft and settings action', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var settings = 0;
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemePreference.instance,
        builder: (_, mode, child) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: mode,
          home: Scaffold(
            body: Column(
              children: [
                AppearanceButton(onSettings: () => settings++),
                TextField(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      'Minha pergunta ainda nao enviada',
    );
    await tester.tap(find.byType(AppearanceButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Tema claro'),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.light,
    );
    expect(controller.text, 'Minha pergunta ainda nao enviada');
    expect(
      (await SharedPreferences.getInstance()).getString('appearance'),
      'light',
    );
    await tester.tap(find.byType(AppearanceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações da IA'));
    await tester.pumpAndSettle();
    expect(settings, 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('editor fits narrow screen in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: Scaffold(
            body: PostEditorDialog(
              title: 'Minha pergunta',
              description: 'Detalhes da minha pergunta',
              code: '',
              onSave: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Minha pergunta'), findsOneWidget);
    });
  }
}
