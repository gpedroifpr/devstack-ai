import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/chat_conversation_service.dart';
import 'package:flutter_application_1/services/chat_history_limits.dart';
import 'package:flutter_application_1/widgets/conversation_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final messages = [
    {
      'text': 'Como usar Flutter?',
      'isUser': true,
      'timestamp': '2026-11-22T12:00:00Z',
    },
  ];
  test(
    'legacy history survives and new conversations remain independent',
    () async {
      SharedPreferences.setMockInitialValues({
        'ai_chat_history_a': messages.map(jsonEncode).toList(),
      });
      final service = ChatConversationService();
      expect(
        (await service.list('a', cloud: false)).single.title,
        'Como usar Flutter?',
      );
      final id = service.newId();
      expect(await service.load('a', id, cloud: false), isEmpty);
      await service.save('a', id, [
        {'text': 'Outro assunto', 'isUser': true},
      ], cloud: false);
      expect((await service.list('a', cloud: false)).length, 2);
      expect(await service.list('b', cloud: false), isEmpty);
      expect(
        await service.load('a', ChatConversationService.legacyId, cloud: false),
        messages,
      );
      await service.save('a', id, [], cloud: false);
      expect(
        (await service.list('a', cloud: false)).single.id,
        ChatConversationService.legacyId,
      );
    },
  );
  test(
    'cleared legacy is not resurrected and conflicts preserve newer history',
    () async {
      SharedPreferences.setMockInitialValues({
        'ai_chat_history_a': messages.map(jsonEncode).toList(),
      });
      final first = ChatConversationService();
      final stale = ChatConversationService();
      const id = ChatConversationService.legacyId;
      await first.load('a', id, cloud: false);
      await stale.load('a', id, cloud: false);
      await first.save('a', id, [], cloud: false);
      await expectLater(
        stale.save('a', id, messages, cloud: false),
        throwsA(isA<ChatHistoryConflict>()),
      );
      expect(await first.list('a', cloud: false), isEmpty);
      expect(await first.load('a', id, cloud: false), isEmpty);
    },
  );
  testWidgets(
    'conversation list highlights selected chat and handles actions',
    (tester) async {
      String? selected;
      var created = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: ConversationList(
                conversations: [
                  ChatConversation('one', 'Como usar Flutter?', DateTime(2026)),
                ],
                selectedId: 'one',
                enabled: true,
                onNew: () => created = true,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<ListTile>(find.byType(ListTile)).selected, isTrue);
      await tester.tap(find.text('Como usar Flutter?'));
      expect(selected, 'one');
      await tester.tap(find.text('Nova conversa'));
      expect(created, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
