import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/optional_post_tags.dart';

void main() {
  testWidgets('tags can be selected, deselected and explicitly cleared', (
    tester,
  ) async {
    var tags = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => OptionalPostTags(
              options: const ['Todos', 'AI', 'Flutter'],
              selected: tags,
              onChanged: (next) => update(() => tags = next),
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected, isTrue);
    await tester.tap(find.text('Flutter'));
    await tester.pump();
    expect(tags, {'Flutter'});
    await tester.tap(find.text('Flutter'));
    await tester.pump();
    expect(tags, isEmpty);
    await tester.tap(find.text('AI'));
    await tester.pump();
    await tester.tap(find.text('Sem tag'));
    await tester.pump();
    expect(tags, isEmpty);
    expect(find.text('Todos'), findsNothing);
  });
}
