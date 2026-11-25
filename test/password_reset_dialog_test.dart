import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/password_reset_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(String) send, {
    String email = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordResetDialog(sendReset: send, initialEmail: email),
        ),
      ),
    );
  }

  testWidgets('invalid email never sends a request', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
    });
    await tester.enterText(find.byType(TextFormField), 'invalido');
    await tester.tap(find.text('Enviar link'));
    await tester.pump();
    expect(calls, 0);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });

  testWidgets(
    'pending request prevents duplicate sends and shows neutral success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(tester, (email) {
        calls++;
        expect(email, 'grupo@example.com');
        return pending.future;
      }, email: 'grupo@example.com');
      await tester.tap(find.text('Enviar link'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Confira seu e-mail'), findsOneWidget);
      expect(find.textContaining('Se houver uma conta'), findsOneWidget);
    },
  );

  testWidgets('failure keeps email editable and allows retry on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await open(tester, (_) async {
      if (++calls == 1) throw Exception();
    }, email: 'grupo@example.com');
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível enviar'), findsOneWidget);
    expect(find.text('grupo@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Confira seu e-mail'), findsOneWidget);
  });
}
