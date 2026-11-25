import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/ai_response_body.dart';

void main() {
  const sample =
      '## Entenda o erro\n\nUm **ponto importante** com `codigo`.\n\n'
      '### Como corrigir\n\n1. Primeiro passo\n2. Segundo passo\n\n'
      '- Uma alternativa\n  - Mais detalhes\n\n'
      '```dart\nfinal exemplo = "uma linha de codigo muito longa para uma tela pequena";\n```\n\n'
      '| Item | Estado |\n| --- | --- |\n| Teste | Pronto |';

  for (final brightness in Brightness.values) {
    testWidgets('markdown hierarchy and code fit mobile in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: AIResponseBody(text: sample),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(markdown.data, sample);
      expect(markdown.selectable, isFalse);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(
        markdown.styleSheet!.h2!.fontSize,
        greaterThan(markdown.styleSheet!.h3!.fontSize!),
      );
      expect(
        markdown.styleSheet!.h3!.fontSize,
        greaterThan(markdown.styleSheet!.p!.fontSize!),
      );
      expect(markdown.styleSheet!.strong!.fontWeight, FontWeight.w700);
      expect(find.byType(Table), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsWidgets,
      );
    });
  }

  testWidgets('remote markdown images do not load external resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AIResponseBody(
            text: '![Legenda](https://example.com/tracker.png)',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Legenda'), findsOneWidget);
  });

  testWidgets('growing Markdown stays ordinary painted text while scrolling', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var text = '';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ListView(
                controller: scroll,
                children: [AIResponseBody(text: text, isRevealing: true)],
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      update(
        () => text +=
            '\n\n## Etapa $i\n\nUma frase que deve permanecer visível durante a escrita.',
      );
      await tester.pump(const Duration(milliseconds: 60));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(SelectionArea), findsNothing);
      expect(find.text('Etapa $i'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
