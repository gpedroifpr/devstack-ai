import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/navigation_viewport.dart';

void main() {
  testWidgets('restores feed position after opening a different screen', (
    tester,
  ) async {
    String location = 'feed';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NavigationViewport(
                location: location,
                child: ListView.builder(
                  itemExtent: 80,
                  itemCount: 100,
                  itemBuilder: (_, index) => Text('$location $index'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(offset, greaterThan(0));
    update(() => location = 'post');
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      0,
    );
    update(() => location = 'feed');
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      offset,
    );
  });

  testWidgets('does not keep inactive screens mounted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NavigationViewport(location: 'a', child: Text('first')),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: NavigationViewport(location: 'b', child: Text('second')),
      ),
    );
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
