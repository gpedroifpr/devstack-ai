import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/post_likes_listener.dart';

void main() {
  testWidgets('new screen subscribes again and empty likes resolves to zero', (
    tester,
  ) async {
    var subscriptions = 0;
    Stream<Set<String>> watch(String id) {
      subscriptions++;
      return Stream.value(<String>{});
    }

    Widget screen() => MaterialApp(
      home: PostLikesListener(
        postId: 'post',
        watchLikes: watch,
        builder: (snapshot, retry) =>
            Text(snapshot.hasData ? '${snapshot.data!.length}' : 'loading'),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(subscriptions, 2);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('retry renews failed subscription and clears the error', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PostLikesListener(
          postId: 'post',
          watchLikes: (_) => ++attempts == 1
              ? Stream<Set<String>>.error(StateError('offline'))
              : Stream.value({'user'}),
          builder: (snapshot, retry) => snapshot.hasError
              ? TextButton(onPressed: retry, child: const Text('retry'))
              : Text(snapshot.hasData ? '${snapshot.data!.length}' : 'loading'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('retry'), findsNothing);
  });
}
