import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/gemini_chat_service.dart';

void main() {
  Map<String, dynamic> turn(String text, bool user, {bool error = false}) => {
    'text': text,
    'isUser': user,
    'isError': error,
  };
  String answer(List<Map<String, dynamic>> parts, {String reason = 'STOP'}) =>
      jsonEncode({
        'candidates': [
          {
            'finishReason': reason,
            'content': {'parts': parts},
          },
        ],
      });

  test(
    'sends prior successful turns, current attachments and separate instructions',
    () async {
      final service = GeminiChatService(
        client: MockClient((request) async {
          expect(request.url.queryParameters.containsKey('key'), isFalse);
          expect(request.headers['x-goog-api-key'], 'test-key');
          final data = jsonDecode(request.body);
          expect(data['systemInstruction'], isNotNull);
          expect(data['contents'].map((e) => e['role']).toList(), [
            'user',
            'model',
            'user',
          ]);
          expect(data['contents'][0]['parts'][0]['text'], 'Meu nome é Ana');
          expect(
            data['contents'][2]['parts'][1]['inline_data']['mime_type'],
            'image/png',
          );
          return http.Response(
            answer([
              {'text': 'Olá, Ana!'},
            ]),
            200,
          );
        }),
      );
      addTearDown(service.close);
      expect(
        await service.send(
          apiKey: 'test-key',
          question: 'Qual meu nome?',
          history: [turn('Meu nome é Ana', true), turn('Olá!', false)],
          attachments: [
            {
              'inline_data': {'mime_type': 'image/png', 'data': 'test'},
            },
          ],
        ),
        'Olá, Ana!',
      );
    },
  );

  test('failed and incomplete turns do not become model context', () {
    expect(
      GeminiChatService.context([
        turn('primeira', true),
        turn('falhou', false, error: true),
        turn('segunda', true),
        turn('## Falha\nStatus: 503', false),
        turn('pendente', true),
      ]),
      isEmpty,
    );
  });

  test('context is limited to ten successful pairs', () {
    final history = [
      for (var i = 0; i < 30; i++) ...[turn('p$i', true), turn('r$i', false)],
    ];
    final context = GeminiChatService.context(history);
    expect(context.length, 20);
    expect((context.first['parts'] as List).first['text'], 'p20');
  });

  test('does not display thought parts', () async {
    final service = GeminiChatService(
      client: MockClient(
        (_) async => http.Response(
          answer([
            {'text': 'pensamento interno', 'thought': true},
            {'text': 'Resposta final'},
          ]),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    expect(
      await service.send(apiKey: 'key', question: 'oi', history: []),
      'Resposta final',
    );
  });

  for (final status in [400, 401, 403, 404, 413, 429, 503, 504]) {
    test(
      'HTTP $status produces a safe error without raw provider details',
      () async {
        final service = GeminiChatService(
          client: MockClient(
            (_) async => http.Response('secret raw data', status),
          ),
        );
        addTearDown(service.close);
        await expectLater(
          service.send(apiKey: 'key', question: 'oi', history: []),
          throwsA(
            isA<AIRequestException>().having(
              (e) => e.message,
              'message',
              isNot(contains('secret')),
            ),
          ),
        );
      },
    );
  }

  test('timeout ends the request without waiting forever', () async {
    final service = GeminiChatService(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    await expectLater(
      service.send(apiKey: 'key', question: 'oi', history: []),
      throwsA(isA<AIRequestException>()),
    );
  });

  for (final body in [
    'not json',
    '{}',
    '{"candidates":[]}',
    '{"candidates":[{"content":{"parts":[]}}]}',
  ]) {
    test(
      'invalid or empty response is not reported as success: $body',
      () async {
        final service = GeminiChatService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(service.close);
        await expectLater(
          service.send(apiKey: 'key', question: 'oi', history: []),
          throwsA(isA<AIRequestException>()),
        );
      },
    );
  }

  test('missing configuration does not call the network', () async {
    final service = GeminiChatService(
      client: MockClient((_) async {
        fail('Unexpected request');
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.send(apiKey: '', question: 'oi', history: []),
      throwsA(isA<AIRequestException>()),
    );
  });
  test('truncated response explicitly warns the user', () async {
    final service = GeminiChatService(
      client: MockClient(
        (_) async => http.Response(
          answer([
            {'text': 'Parte'},
          ], reason: 'MAX_TOKENS'),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    expect(
      await service.send(apiKey: 'key', question: 'oi', history: []),
      contains('interrompida'),
    );
  });
}
