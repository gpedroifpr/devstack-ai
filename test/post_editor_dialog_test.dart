import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/post_update.dart';
import 'package:flutter_application_1/widgets/post_editor_dialog.dart';

Future<void> openEditor(
  WidgetTester tester,
  Future<void> Function(PostUpdate) save,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('open'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PostEditorDialog(
                title: 'Titulo original',
                description: 'Descricao original da duvida',
                code: '',
                onSave: save,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validation prevents saving empty title', (tester) async {
    var calls = 0;
    await openEditor(tester, (_) async {
      calls++;
    });
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Use pelo menos 6 caracteres.'), findsOneWidget);
  });
  testWidgets('failed save preserves draft and permits retry', (tester) async {
    await openEditor(tester, (_) async => throw StateError('offline'));
    await tester.enterText(find.byType(TextFormField).first, 'Titulo alterado');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Titulo alterado'), findsOneWidget);
    expect(find.textContaining('Seu texto foi mantido'), findsOneWidget);
  });
  testWidgets(
    'pending save blocks duplicate submission and dismisses on success',
    (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await openEditor(tester, (_) {
        calls++;
        return completer.future;
      });
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PostEditorDialog), findsNothing);
    },
  );
  testWidgets('mobile editor fits and cancellation writes nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await openEditor(tester, (_) async {
      calls++;
    });
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    expect(find.byType(PostEditorDialog), findsNothing);
  });
}
