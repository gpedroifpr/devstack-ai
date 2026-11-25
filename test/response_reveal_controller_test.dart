import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/response_reveal_controller.dart';

void main() {
  testWidgets('reveals gradually and preserves complete Markdown and Unicode', (
    tester,
  ) async {
    final controller = ResponseRevealController();
    addTearDown(controller.dispose);
    const answer =
        '## Explicação\n\nOlá 👩🏽‍💻!\n\n```dart\nprint("oi");\n```';
    controller.start(answer);
    expect(controller.isRevealing, isTrue);
    expect(controller.text.length, lessThan(answer.length));
    final first = controller.text;
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.text.length, greaterThan(first.length));
    await tester.pump(const Duration(seconds: 20));
    expect(controller.text, answer);
    expect(controller.isRevealing, isFalse);
  });

  testWidgets(
    'new response cancels previous animation and supports reduced motion',
    (tester) async {
      final controller = ResponseRevealController();
      addTearDown(controller.dispose);
      controller.start('a' * 1000);
      controller.start('Resposta nova', animate: false);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.text, 'Resposta nova');
      expect(controller.isRevealing, isFalse);
    },
  );

  testWidgets('finishing and disposing cancel timers', (tester) async {
    final controller = ResponseRevealController();
    controller.start('x' * 500);
    controller.finish();
    expect(controller.text.length, 500);
    controller.start('y' * 500);
    controller.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
