import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_history_limits.dart';

class ChatConversation {
  final String id;
  final String title;
  final DateTime updatedAt;
  const ChatConversation(this.id, this.title, this.updatedAt);
}

class ChatConversationService {
  static const legacyId = 'ai_chat_history';
  final Map<String, int> _revisions = {};
  String newId() =>
      'ai_chat_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
  String _key(String user, String id) => 'conversation_${user}_$id';
  CollectionReference<Map<String, dynamic>> _collection(String user) {
    if (FirebaseAuth.instance.currentUser?.uid != user) {
      throw StateError('Entre novamente para acessar suas conversas.');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user)
        .collection('private');
  }

  static String titleFor(List<Map<String, dynamic>> messages) {
    final question = messages.where((m) => m['isUser'] == true).firstOrNull;
    final text = (question?['text']?.toString() ?? '').trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return text.isEmpty
        ? 'Nova conversa'
        : text.substring(0, min(65, text.length));
  }

  Future<List<ChatConversation>> list(
    String user, {
    required bool cloud,
  }) async {
    final records = <String, Map<String, dynamic>>{};
    if (cloud) {
      final collection = _collection(user);
      final snapshot = await collection
          .where('kind', isEqualTo: 'chat')
          .get(const GetOptions(source: Source.server));
      for (final doc in snapshot.docs) {
        records[doc.id] = doc.data();
      }
      final legacy = await collection
          .doc(legacyId)
          .get(const GetOptions(source: Source.server));
      if (legacy.exists) records[legacyId] = legacy.data()!;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'conversation_${user}_';
      for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        records[key.substring(prefix.length)] = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(key)!),
        );
      }
      if (!records.containsKey(legacyId)) {
        records[legacyId] = {
          'messages': (prefs.getStringList('ai_chat_history_$user') ?? [])
              .map(jsonDecode)
              .toList(),
        };
      }
    }
    final result = <ChatConversation>[];
    for (final entry in records.entries) {
      final messages = (entry.value['messages'] as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      if (messages.isEmpty) continue;
      final stamp = entry.value['updatedAt'];
      final date = stamp is Timestamp
          ? stamp.toDate()
          : DateTime.tryParse(
                  stamp?.toString() ??
                      messages.last['timestamp']?.toString() ??
                      '',
                ) ??
                DateTime(2000);
      result.add(
        ChatConversation(
          entry.key,
          entry.value['title']?.toString() ?? titleFor(messages),
          date,
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<List<Map<String, dynamic>>> load(
    String user,
    String id, {
    required bool cloud,
  }) async {
    Map<String, dynamic> data;
    if (cloud) {
      data =
          (await _collection(
            user,
          ).doc(id).get(const GetOptions(source: Source.server))).data() ??
          {};
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(user, id));
      data = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
      if (raw == null && id == legacyId) {
        data['messages'] = (prefs.getStringList('ai_chat_history_$user') ?? [])
            .map(jsonDecode)
            .toList();
      }
    }
    _revisions[_key(user, id)] = (data['revision'] as num?)?.toInt() ?? 0;
    return (data['messages'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  Future<void> save(
    String user,
    String id,
    List<Map<String, dynamic>> messages, {
    required bool cloud,
  }) async {
    final key = _key(user, id);
    final expected = _revisions[key];
    if (expected == null) {
      throw StateError('Carregue a conversa antes de salvar.');
    }
    final data = <String, dynamic>{
      'kind': 'chat',
      'title': titleFor(messages),
      'messages': boundedChatHistory(messages),
      'revision': expected + 1,
    };
    if (cloud) {
      final ref = _collection(user).doc(id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final current = await tx.get(ref);
        if (((current.data()?['revision'] as num?)?.toInt() ?? 0) != expected) {
          throw const ChatHistoryConflict();
        }
        tx.set(ref, {...data, 'updatedAt': FieldValue.serverTimestamp()});
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final current = raw == null
          ? 0
          : (jsonDecode(raw)['revision'] as num).toInt();
      if (current != expected) throw const ChatHistoryConflict();
      final ok = await prefs.setString(
        key,
        jsonEncode({...data, 'updatedAt': DateTime.now().toIso8601String()}),
      );
      if (!ok) throw StateError('Não foi possível salvar a conversa.');
    }
    _revisions[key] = expected + 1;
  }
}
