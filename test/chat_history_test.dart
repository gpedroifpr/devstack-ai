import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/chat_history_limits.dart';
import 'package:flutter_application_1/services/local_database_service.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('history keeps newest 80 messages in order', () {
    final result = boundedChatHistory([
      for (var i = 0; i < 100; i++) {'text': '$i'},
    ]);
    expect(result.length, 80);
    expect(result.first['text'], '20');
    expect(result.last['text'], '99');
  });
  test('size cap accounts for UTF8 and does not modify originals', () {
    final source = [
      for (var i = 0; i < 20; i++) {'text': List.filled(10000, 'á').join()},
    ];
    final result = boundedChatHistory(source);
    expect(utf8.encode(jsonEncode(result)).length, lessThan(610000));
    expect(source.length, 20);
  });
  test(
    'a single oversized message fails rather than silently deleting history',
    () {
      expect(
        () => boundedChatHistory([
          {'text': List.filled(700000, 'a').join()},
        ]),
        throwsStateError,
      );
    },
  );
  test(
    'local histories are isolated and clearing one preserves the other',
    () async {
      final db = LocalDatabaseService();
      await db.saveAIChatHistory('a', [
        {'text': 'one'},
      ]);
      await db.saveAIChatHistory('b', [
        {'text': 'two'},
      ]);
      await db.clearAIChatHistory('a');
      expect(await db.loadAIChatHistory('a'), isEmpty);
      expect((await db.loadAIChatHistory('b')).single['text'], 'two');
    },
  );
  test('message metadata and error state survive reload', () {
    final message = ChatMessage.fromJson({
      'text': 'erro',
      'requestText': 'pergunta completa',
      'isUser': false,
      'isError': true,
      'timestamp': '2026-11-17T12:00:00Z',
      'attachments': [
        {'type': 'imagem', 'title': 'erro.png', 'fileName': 'erro.png'},
      ],
    });
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.isError, isTrue);
    expect(restored.requestText, 'pergunta completa');
    expect(restored.attachments.single.title, 'erro.png');
    expect(restored.attachments.single.bytes, isNull);
  });
}
