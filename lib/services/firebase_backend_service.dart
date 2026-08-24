import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_database_service.dart';

class FirebaseBackendService {
  static bool _isInitialized = false;
  static String? _initializationError;

  static bool get isInitialized => _isInitialized;

  static String? get initializationError => _initializationError;

  static Future<void> initializeFromEnv() async {
    if (_isInitialized || Firebase.apps.isNotEmpty) {
      _isInitialized = true;
      return;
    }

    final apiKey = _env('FIREBASE_API_KEY');
    final appId = _env('FIREBASE_APP_ID');
    final messagingSenderId = _env('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _env('FIREBASE_PROJECT_ID');
    final authDomain = _env('FIREBASE_AUTH_DOMAIN');
    final storageBucket = _env('FIREBASE_STORAGE_BUCKET');

    final hasMinimumConfig =
        apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty;

    if (!hasMinimumConfig) {
      _initializationError = 'Credenciais do Firebase ausentes no .env.';
      return;
    }

    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          authDomain: authDomain.isEmpty ? null : authDomain,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        ),
      );

      _isInitialized = true;
      _initializationError = null;
    } catch (error) {
      _isInitialized = false;
      _initializationError = error.toString();
    }
  }

  Future<LocalAuthUser?> loadCurrentUser() async {
    if (!_isInitialized) return null;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    String? username;
    String? photoBase64;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final data = doc.data();
      username = data?['username']?.toString();
      photoBase64 = data?['photoBase64']?.toString();
    } catch (_) {
      // Mantem login funcionando mesmo se o Firestore negar leitura.
    }

    return LocalAuthUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? _nameFromEmail(firebaseUser.email),
      username: username,
      email: firebaseUser.email ?? '',
      photoBase64: photoBase64,
    );
  }

  Future<AuthResult> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      return AuthResult.failure('Firebase ainda não foi configurado.');
    }

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return AuthResult.failure('Não foi possível criar o usuário.');
      }

      await firebaseUser.updateDisplayName(name.trim());

      final user = LocalAuthUser(
        id: firebaseUser.uid,
        name: name.trim(),
        email: firebaseUser.email ?? email.trim(),
      );

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.id).set({
          'id': user.id,
          'name': user.name,
          'username': user.username,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // O cadastro continua válido mesmo se o Firestore ainda não estiver pronto.
      }

      return AuthResult.success(user);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_authErrorMessage(error));
    } catch (_) {
      return AuthResult.failure('Erro ao cadastrar no Firebase.');
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      return AuthResult.failure('Firebase ainda não foi configurado.');
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return AuthResult.failure('Não foi possível entrar.');
      }

      return AuthResult.success(
        LocalAuthUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? _nameFromEmail(firebaseUser.email),
          email: firebaseUser.email ?? email.trim(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_authErrorMessage(error));
    } catch (_) {
      return AuthResult.failure('Erro ao entrar com Firebase.');
    }
  }

  Future<void> signOut() async {
    if (!_isInitialized) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<LocalAuthUser?> updateCurrentUserProfile({
    required String name,
    required String username,
    String? photoBase64,
  }) async {
    if (!_isInitialized) return null;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    final normalizedName = name.trim();
    final normalizedUsername = username.trim().startsWith('@')
        ? username.trim()
        : '@${username.trim()}';

    await firebaseUser.updateDisplayName(normalizedName);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .set({
          'id': firebaseUser.uid,
          'name': normalizedName,
          'username': normalizedUsername,
          'email': firebaseUser.email ?? '',
          'photoBase64': photoBase64,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    return LocalAuthUser(
      id: firebaseUser.uid,
      name: normalizedName,
      username: normalizedUsername,
      email: firebaseUser.email ?? '',
      photoBase64: photoBase64,
    );
  }

  Future<void> saveUserPost(Map<String, dynamic> post) async {
    if (!_isInitialized) return;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(post['id'].toString())
        .set({
          ...post,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> loadUserPosts() async {
    if (!_isInitialized) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadCustomCommunities() async {
    if (!_isInitialized) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomCommunity(Map<String, dynamic> community) async {
    if (!_isInitialized) return;

    await FirebaseFirestore.instance
        .collection('communities')
        .doc(community['id'].toString())
        .set({
          ...community,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> loadAIChatHistory(String userId) async {
    if (!_isInitialized || userId.isEmpty || userId == 'guest') return [];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('private')
          .doc('ai_chat_history')
          .get();

      final data = doc.data();
      final messages = data?['messages'];
      if (messages is! List) return [];

      return messages
          .whereType<Map<String, dynamic>>()
          .map((message) => Map<String, dynamic>.from(message))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAIChatHistory(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (!_isInitialized || userId.isEmpty || userId == 'guest') return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('ai_chat_history')
        .set({
          'messages': messages.length > 80
              ? messages.sublist(messages.length - 80)
              : messages,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> clearAIChatHistory(String userId) async {
    if (!_isInitialized || userId.isEmpty || userId == 'guest') return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('ai_chat_history')
        .delete();
  }

  Future<List<Map<String, dynamic>>> loadPostComments() async {
    if (!_isInitialized) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('comments')
          .limit(200)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePostComment(Map<String, dynamic> comment) async {
    if (!_isInitialized) return;

    final postId = comment['postId']?.toString();
    final commentId = comment['id']?.toString();
    if (postId == null || postId.isEmpty || commentId == null) return;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .set({
          ...comment,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static String _env(String key) {
    final dotenvValue = (dotenv.env[key] ?? '').trim();
    if (dotenvValue.isNotEmpty) return dotenvValue;

    switch (key) {
      case 'FIREBASE_API_KEY':
        return const String.fromEnvironment('FIREBASE_API_KEY').trim();
      case 'FIREBASE_APP_ID':
        return const String.fromEnvironment('FIREBASE_APP_ID').trim();
      case 'FIREBASE_MESSAGING_SENDER_ID':
        return const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ).trim();
      case 'FIREBASE_PROJECT_ID':
        return const String.fromEnvironment('FIREBASE_PROJECT_ID').trim();
      case 'FIREBASE_AUTH_DOMAIN':
        return const String.fromEnvironment('FIREBASE_AUTH_DOMAIN').trim();
      case 'FIREBASE_STORAGE_BUCKET':
        return const String.fromEnvironment('FIREBASE_STORAGE_BUCKET').trim();
      default:
        return '';
    }
  }

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'Usuário DevStack';
    return email.split('@').first;
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail.';
      case 'invalid-email':
        return 'Informe um e-mail válido.';
      case 'weak-password':
        return 'A senha é fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'network-request-failed':
        return 'Sem conexão com o Firebase. Verifique sua internet.';
      default:
        return error.message ?? 'Erro de autenticação no Firebase.';
    }
  }
}
