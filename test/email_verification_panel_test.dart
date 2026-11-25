import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/email_verification_panel.dart';

Widget host({
  required Future<bool> Function() refresh,
  required Future<void> Function() send,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: EmailVerificationPanel(
        email: 'pedro@example.com',
        refresh: refresh,
        send: send,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'sending does not mark verified and cooldown prevents duplicates',
    (tester) async {
      var sent = 0;
      var verified = false;
      await tester.pumpWidget(
        host(
          refresh: () async => verified,
          send: () async {
            sent++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('E-mail não confirmado'), findsOneWidget);
      await tester.tap(find.text('Enviar confirmação'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(find.text('E-mail não confirmado'), findsOneWidget);
      expect(find.text('Reenviar em 60s'), findsOneWidget);
      verified = true;
      await tester.tap(find.text('Já confirmei'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail confirmado'), findsOneWidget);
      expect(find.text('Já confirmei'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed send allows retry and does not report success', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        refresh: () async => false,
        send: () async => throw StateError('offline'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar confirmação'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível'), findsOneWidget);
    expect(find.textContaining('Link enviado'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('narrow viewport fits and initial error can be retried', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      host(
        refresh: () async {
          if (++calls == 1) throw StateError('offline');
          return false;
        },
        send: () async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('E-mail confirmado'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar confirmação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
