import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_database_service.dart';
import 'google_auth_errors.dart';
import 'chat_history_limits.dart';
import '../models/post_update.dart';

class FirebaseBackendService {
  final Map<String, int> _chatRevisions = {};
  static bool _isInitialized = false;
  static String? _initializationError;
  static final Map<String, DateTime> _verificationSentAt = {};

  Future<bool> refreshEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null || refreshed.uid != user.uid) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    return refreshed.emailVerified;
  }

  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final lastSent = _verificationSentAt[user.uid];
    if (lastSent != null &&
        DateTime.now().difference(lastSent).inSeconds < 60) {
      throw FirebaseAuthException(code: 'too-many-requests');
    }
    await FirebaseAuth.instance.setLanguageCode('pt-BR');
    await user.sendEmailVerification();
    _verificationSentAt[user.uid] = DateTime.now();
  }

  static bool get isInitialized => _isInitialized;

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.setLanguageCode('pt-BR');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep the response identical for registered and unknown addresses.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  static String? get initializationError => _initializationError;

  Future<Set<String>> loadFavoritedPostIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('saved_posts')
        .get();
    return List<String>.from(
      snapshot.data()?['ids'] ?? const <String>[],
    ).toSet();
  }

  Future<void> savePostFavorite(String postId, bool isFavorited) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Entre para salvar publicações.');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('saved_posts')
        .set({
          'ids': isFavorited
              ? FieldValue.arrayUnion([postId])
              : FieldValue.arrayRemove([postId]),
        }, SetOptions(merge: true));
  }

  Stream<Set<String>> watchPostLikes(String postId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> setPostLiked(String postId, bool liked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isInitialized || user == null) {
      throw StateError('Entre na sua conta para curtir.');
    }
    final reference = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);
    if (liked) {
      await reference.set({'userId': user.uid});
    } else {
      await reference.delete();
    }
  }

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
    String? profileName;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final data = doc.data();
      username = data?['username']?.toString();
      profileName = data?['name']?.toString();
      photoBase64 = data?['photoBase64']?.toString();
    } catch (_) {
      // Mantem login funcionando mesmo se o Firestore negar leitura.
    }

    return LocalAuthUser(
      id: firebaseUser.uid,
      name:
          profileName ??
          firebaseUser.displayName ??
          _nameFromEmail(firebaseUser.email),
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

      final profile = await loadCurrentUser();
      if (profile == null) {
        return AuthResult.failure('Entre novamente na sua conta.');
      }
      return AuthResult.success(profile);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_authErrorMessage(error));
    } catch (_) {
      return AuthResult.failure('Erro ao entrar com Firebase.');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    if (!_isInitialized) {
      return AuthResult.failure('Firebase não está conectado.');
    }
    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final credential = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = credential.user;
      if (user == null) return AuthResult.failure('Não foi possível entrar.');
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final fallback = LocalAuthUser(
        id: user.uid,
        name: user.displayName ?? _nameFromEmail(user.email),
        email: user.email ?? '',
      );
      try {
        // Existing profiles retain their chosen name, handle and uploaded photo.
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(reference);
          if (!snapshot.exists) {
            transaction.set(reference, {
              'id': user.uid,
              'name': fallback.name,
              'username': fallback.username,
              'email': fallback.email,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
        final snapshot = await reference.get();
        final data = snapshot.data();
        return AuthResult.success(
          LocalAuthUser(
            id: user.uid,
            name: data?['name']?.toString() ?? fallback.name,
            username: data?['username']?.toString() ?? fallback.username,
            email: user.email ?? '',
            photoBase64: data?['photoBase64']?.toString(),
          ),
        );
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        return AuthResult.failure(
          'O Google autorizou a entrada, mas não conseguimos carregar seu perfil. Confira a conexão e tente novamente.',
        );
      }
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(googleAuthErrorMessage(error.code));
    } catch (_) {
      return AuthResult.failure(
        'Não foi possível entrar com Google. Tente novamente.',
      );
    }
  }

  Future<void> signOut() async {
    if (!_isInitialized) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<void> updateProfilePhoto(String photoBase64) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Entre novamente para trocar sua foto.');
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.set(db.collection('users').doc(user.uid), {
      'photoBase64': photoBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(db.collection('publicAvatars').doc(user.uid), {
      'photoBase64': photoBase64,
    });
    await batch.commit();
  }

  Future<void> syncPublicAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isInitialized || user == null) return;
    final db = FirebaseFirestore.instance;
    final publicRef = db.collection('publicAvatars').doc(user.uid);
    // Read the authoritative photo in the transaction so another tab's update
    // cannot be overwritten by an older session during migration.
    await db.runTransaction((tx) async {
      final private = await tx.get(db.collection('users').doc(user.uid));
      final public = await tx.get(publicRef);
      final photo = private.data()?['photoBase64'];
      if (photo is String &&
          photo.isNotEmpty &&
          public.data()?['photoBase64'] != photo) {
        tx.set(publicRef, {'photoBase64': photo});
      }
    });
  }

  Stream<String?> watchAuthorPhoto(String userId) {
    return FirebaseFirestore.instance
        .collection('publicAvatars')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['photoBase64'] as String?);
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

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.set(db.collection('users').doc(firebaseUser.uid), {
      'id': firebaseUser.uid,
      'name': normalizedName,
      'username': normalizedUsername,
      'email': firebaseUser.email ?? '',
      'photoBase64': photoBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (photoBase64 != null) {
      batch.set(db.collection('publicAvatars').doc(firebaseUser.uid), {
        'photoBase64': photoBase64,
      });
    }
    await batch.commit();

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

  Future<void> updateUserPost(String postId, PostUpdate update) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Entre na sua conta.');
    final changes = update.toJson();
    final reference = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data()?['authorId'] != user.uid) {
        throw StateError('Somente o autor pode alterar esta publicação.');
      }
      transaction.update(reference, {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> loadUserPosts() async {
    if (!_isInitialized) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .get();

      final posts = snapshot.docs
          .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
          .toList();
      // Saved posts must remain reachable even after leaving the recent feed.
      try {
        final loadedIds = snapshot.docs.map((doc) => doc.id).toSet();
        final missing = (await loadFavoritedPostIds())
            .difference(loadedIds)
            .toList();
        for (var offset = 0; offset < missing.length; offset += 10) {
          final batch = await FirebaseFirestore.instance
              .collection('posts')
              .where(
                FieldPath.documentId,
                whereIn: missing.skip(offset).take(10).toList(),
              )
              .get();
          posts.addAll(
            batch.docs.map(
              (doc) => <String, dynamic>{...doc.data(), 'id': doc.id},
            ),
          );
        }
      } catch (_) {
        // The profile-state loader surfaces failures without hiding the recent feed.
      }
      return posts;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Entre na sua conta para criar comunidades.');
    }
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(
      firestore.collection('communities').doc(community['id'].toString()),
      {
        ...community,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      firestore
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('community_follows'),
      {
        'ids': FieldValue.arrayUnion([community['id'].toString()]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<Set<String>> loadFollowedCommunityIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('community_follows')
        .get();
    return List<String>.from(doc.data()?['ids'] ?? const <String>[]).toSet();
  }

  Future<void> setCommunityFollowed(String communityId, bool followed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Entre na sua conta para seguir comunidades.');
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('community_follows')
        .set({
          'ids': followed
              ? FieldValue.arrayUnion([communityId])
              : FieldValue.arrayRemove([communityId]),
        }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> loadAIChatHistory(String userId) async {
    _requireChatOwner(userId);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('ai_chat_history')
        .get(const GetOptions(source: Source.server));

    final data = doc.data();
    _chatRevisions[userId] = (data?['revision'] as num?)?.toInt() ?? 0;
    final messages = data?['messages'];
    if (messages is! List) return [];

    return messages
        .whereType<Map<String, dynamic>>()
        .map((message) => Map<String, dynamic>.from(message))
        .toList();
  }

  void _requireChatOwner(String userId) {
    if (!_isInitialized ||
        userId.isEmpty ||
        userId == 'guest' ||
        FirebaseAuth.instance.currentUser?.uid != userId) {
      throw StateError('Entre novamente para acessar seu histórico.');
    }
  }

  Future<void> saveAIChatHistory(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    _requireChatOwner(userId);
    final expected = _chatRevisions[userId];
    if (expected == null) {
      throw StateError('Carregue o histórico antes de salvar.');
    }
    final reference = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('ai_chat_history');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final current = await transaction.get(reference);
      final revision = (current.data()?['revision'] as num?)?.toInt() ?? 0;
      if (revision != expected) throw const ChatHistoryConflict();
      transaction.set(reference, {
        'messages': boundedChatHistory(messages),
        'revision': revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    _chatRevisions[userId] = expected + 1;
  }

  Future<void> clearAIChatHistory(String userId) async {
    // Keep a revision tombstone so an older tab cannot restore deleted messages.
    await saveAIChatHistory(userId, const []);
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

  Stream<List<Map<String, dynamic>>> watchPostComments() {
    return FirebaseFirestore.instance
        .collectionGroup('comments')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
              .toList(),
        );
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
