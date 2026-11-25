import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIRequestException implements Exception {
  const AIRequestException(this.message);
  final String message;
}

class GeminiChatService {
  GeminiChatService({
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  void close() => _client.close();

  static List<Map<String, dynamic>> context(
    List<Map<String, dynamic>> history,
  ) {
    final pairs = <List<Map<String, dynamic>>>[];
    Map<String, dynamic>? pending;
    for (final message in history) {
      if (message['isUser'] == true) {
        pending = message;
      } else {
        if (pending != null &&
            message['isError'] != true &&
            !(message['text']?.toString().startsWith('## ') == true &&
                message['text'].toString().contains('Status:'))) {
          pairs.add([
            {
              'role': 'user',
              'parts': [
                {'text': pending['requestText'] ?? pending['text']},
              ],
            },
            {
              'role': 'model',
              'parts': [
                {'text': message['text']},
              ],
            },
          ]);
        }
        pending = null;
      }
    }
    final selected = <List<Map<String, dynamic>>>[];
    var size = 0;
    for (final pair in pairs.reversed.take(10)) {
      final length = jsonEncode(pair).length;
      if (size + length > 40000) break;
      selected.insert(0, pair);
      size += length;
    }
    return selected.expand((pair) => pair).toList();
  }

  Future<String> send({
    required String apiKey,
    required String question,
    required List<Map<String, dynamic>> history,
    List<Map<String, dynamic>> attachments = const [],
    String model = 'gemini-2.5-flash',
  }) async {
    if (apiKey.isEmpty || apiKey.contains('SUA_CHAVE')) {
      throw const AIRequestException(
        'A IA não está configurada nesta versão. Avise a equipe do DevStack.',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {
                    'text':
                        'Você é o Assistente DevStack. Responda em português do Brasil, com clareza e exemplos de código quando úteis. Organize respostas longas em seções com títulos Markdown ## e subtítulos ###, separados dos parágrafos por uma linha em branco. Use listas quando ajudarem, negrito para pontos importantes e blocos de código com a linguagem indicada. Não crie seções desnecessárias em respostas curtas. Use o histórico como contexto. Imagens de mensagens anteriores podem não estar disponíveis; peça para reenviar quando necessário. Nunca invente o conteúdo de um anexo ausente.',
                  },
                ],
              },
              'contents': [
                ...context(history),
                {
                  'role': 'user',
                  'parts': [
                    {'text': question},
                    ...attachments,
                  ],
                },
              ],
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AIRequestException(switch (response.statusCode) {
          429 =>
            'O limite de uso da IA foi atingido. Aguarde e tente novamente mais tarde.',
          401 || 403 =>
            'A configuração de acesso à IA precisa ser revisada pela equipe.',
          404 =>
            'O modelo de IA configurado está indisponível. Avise a equipe.',
          400 || 413 =>
            'A pergunta ou os anexos não puderam ser processados. Reduza o conteúdo e tente novamente.',
          503 =>
            'A IA está ocupada agora. Tente novamente em alguns instantes.',
          _ =>
            'O serviço de IA está indisponível no momento. Tente novamente mais tarde.',
        });
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const AIRequestException(
          'A IA não retornou uma resposta. Reformule a pergunta e tente novamente.',
        );
      }
      final candidate = candidates.first as Map<String, dynamic>;
      final reason = candidate['finishReason'];
      if (reason != null && reason != 'STOP' && reason != 'MAX_TOKENS') {
        throw const AIRequestException(
          'A resposta foi interrompida pelo serviço. Reformule a pergunta.',
        );
      }
      final parts = candidate['content']?['parts'];
      final text = parts is List
          ? parts
                .whereType<Map>()
                .where((p) => p['thought'] != true)
                .map((p) => p['text'] is String ? p['text'] as String : '')
                .join('\n')
                .trim()
          : '';
      if (text.isEmpty) {
        throw const AIRequestException(
          'A IA retornou uma resposta vazia. Tente reformular a pergunta.',
        );
      }
      return reason == 'MAX_TOKENS'
          ? '$text\n\n*Resposta interrompida pelo limite de tamanho. Peça para continuar.*'
          : text;
    } on AIRequestException {
      rethrow;
    } on TimeoutException {
      throw const AIRequestException(
        'A IA demorou além do limite de espera. Tente novamente em instantes.',
      );
    } catch (_) {
      throw const AIRequestException(
        'Não foi possível obter a resposta. Confira sua conexão e tente novamente.',
      );
    }
  }
}
