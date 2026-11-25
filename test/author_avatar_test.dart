import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/widgets/author_avatar.dart';
import 'package:flutter_application_1/services/local_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String photo;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xffee2222), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    photo = base64Encode(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  Widget app({String? value, Stream<String?>? stream}) => MaterialApp(
    home: Scaffold(
      body: AuthorAvatar(
        radius: 18,
        color: Colors.cyan,
        photo: value,
        photos: stream,
      ),
    ),
  );

  testWidgets('default avatar survives missing or malformed data', (
    tester,
  ) async {
    for (final value in [null, '', 'not base64!!!']) {
      await tester.pumpWidget(app(value: value));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('author photo updates without changing its layout size', (
    tester,
  ) async {
    final stream = StreamController<String?>();
    addTearDown(stream.close);
    await tester.pumpWidget(app(stream: stream.stream));
    expect(find.byIcon(Icons.person), findsOneWidget);
    stream.add(photo);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(AuthorAvatar)), const Size(36, 36));
    stream.add(null);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
  test('local lookup returns only the requested author photo', () async {
    SharedPreferences.setMockInitialValues({
      'registered_users': [
        jsonEncode({
          'id': 'one',
          'photoBase64': photo,
          'email': 'private@example.test',
        }),
        jsonEncode({'id': 'two', 'photoBase64': 'other'}),
      ],
    });
    final db = LocalDatabaseService();
    expect(await db.loadAuthorPhoto('one'), photo);
    expect(await db.loadAuthorPhoto('two'), 'other');
    expect(await db.loadAuthorPhoto('missing'), isNull);
  });
}
