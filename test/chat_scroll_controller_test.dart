import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/chat_scroll_controller.dart';

void main() {
  testWidgets(
    'follows new question and response from old variable-height messages',
    (tester) async {
      final controller = ChatScrollController();
      addTearDown(controller.dispose);
      var count = 80;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return ListView.builder(
                  controller: controller,
                  itemCount: count,
                  itemBuilder: (_, index) => SizedBox(
                    height: index.isEven ? 60 : 400,
                    child: Text('message $index'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      for (var turn = 0; turn < 2; turn++) {
        controller.jumpTo(0);
        update(() => count++);
        controller.followLatest();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(controller.position.extentAfter, lessThan(1));
        expect(find.text('message ${count - 1}'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'cancelled follow does not move a reader away from older messages',
    (tester) async {
      final controller = ChatScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: List.generate(
                50,
                (i) => SizedBox(height: 100, child: Text('$i')),
              ),
            ),
          ),
        ),
      );
      controller.followLatest();
      controller.cancelFollow();
      controller.followGrowingResponse();
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
    },
  );

  testWidgets('pending follow is safe when screen closes', (tester) async {
    final controller = ChatScrollController();
    controller.followLatest();
    controller.dispose();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
