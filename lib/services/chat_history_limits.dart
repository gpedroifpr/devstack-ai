import 'dart:convert';

class ChatHistoryConflict implements Exception {
  const ChatHistoryConflict();
}

List<Map<String, dynamic>> boundedChatHistory(
  List<Map<String, dynamic>> messages,
) {
  final result = <Map<String, dynamic>>[];
  var bytes = 0;
  for (final message in messages.reversed.take(80)) {
    final size = utf8.encode(jsonEncode(message)).length;
    if (size > 600000) {
      throw StateError('Uma mensagem excedeu o limite do histórico.');
    }
    if (bytes + size > 600000) break;
    result.insert(0, message);
    bytes += size;
  }
  return result;
}
