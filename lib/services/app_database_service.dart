import 'package:flutter/foundation.dart';

import 'firebase_backend_service.dart';
import 'local_database_service.dart';

export 'local_database_service.dart' show AuthResult, LocalAuthUser;

class AppDatabaseService {
  final LocalDatabaseService _localService = LocalDatabaseService();
  final FirebaseBackendService _firebaseService = FirebaseBackendService();

  bool get isUsingFirebase => FirebaseBackendService.isInitialized;

  String get backendStatusMessage {
    if (isUsingFirebase) return 'Cadastro conectado ao Firebase Auth.';

    final error = FirebaseBackendService.initializationError;
    if (kReleaseMode) {
      return error == null
          ? 'Firebase não foi configurado neste build publicado.'
          : 'Firebase não iniciou neste build: $error';
    }

    return 'Cadastro local para protótipo. Configure o .env para ativar Firebase Auth.';
  }

  Future<LocalAuthUser?> loadCurrentUser() async {
    if (isUsingFirebase) {
      return _firebaseService.loadCurrentUser();
    }

    return _localService.loadCurrentUser();
  }

  Future<AuthResult> registerUser({
    required String name,
    required String email,
    required String password,
  }) {
    if (isUsingFirebase) {
      return _firebaseService.registerUser(
        name: name,
        email: email,
        password: password,
      );
    }

    if (kReleaseMode) {
      return Future.value(AuthResult.failure(_firebaseMissingMessage()));
    }

    return _localService.registerUser(
      name: name,
      email: email,
      password: password,
    );
  }

  Future<AuthResult> signIn({required String email, required String password}) {
    if (isUsingFirebase) {
      return _firebaseService.signIn(email: email, password: password);
    }

    if (kReleaseMode) {
      return Future.value(AuthResult.failure(_firebaseMissingMessage()));
    }

    return _localService.signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    if (isUsingFirebase) {
      await _firebaseService.signOut();
      return;
    }

    await _localService.signOut();
  }

  Future<LocalAuthUser?> updateCurrentUserProfile({
    required String name,
    required String username,
    String? photoBase64,
  }) async {
    if (isUsingFirebase) {
      try {
        return await _firebaseService.updateCurrentUserProfile(
          name: name,
          username: username,
          photoBase64: photoBase64,
        );
      } catch (_) {
        // Cai para o perfil local quando o Firestore estiver sem permissão.
      }
    }

    return _localService.updateCurrentUserProfile(
      name: name,
      username: username,
      photoBase64: photoBase64,
    );
  }

  Future<Set<String>> loadLikedPostIds() {
    return _localService.loadLikedPostIds();
  }

  Future<Set<String>> loadFavoritedPostIds() {
    return _localService.loadFavoritedPostIds();
  }

  Future<void> savePostLike(String postId, bool isLiked) {
    return _localService.savePostLike(postId, isLiked);
  }

  Future<void> savePostFavorite(String postId, bool isFavorited) {
    return _localService.savePostFavorite(postId, isFavorited);
  }

  Future<List<String>> loadSearchHistory() {
    return _localService.loadSearchHistory();
  }

  Future<List<String>> saveSearchQuery(
    String query,
    List<String> currentHistory,
  ) {
    return _localService.saveSearchQuery(query, currentHistory);
  }

  Future<List<Map<String, dynamic>>> loadUserPosts() async {
    final localPosts = await _localService.loadUserPosts();

    if (!isUsingFirebase) {
      return localPosts;
    }

    final cloudPosts = await _firebaseService.loadUserPosts();
    final mergedPosts = <Map<String, dynamic>>[];
    final usedIds = <String>{};

    for (final post in [...cloudPosts, ...localPosts]) {
      final id = post['id']?.toString();
      if (id == null || usedIds.contains(id)) continue;

      usedIds.add(id);
      mergedPosts.add(post);
    }

    return mergedPosts;
  }

  Future<void> saveUserPost(Map<String, dynamic> post) async {
    await _localService.saveUserPost(post);

    if (isUsingFirebase) {
      try {
        await _firebaseService.saveUserPost(post);
      } catch (_) {
        // Mantem o protótipo funcionando mesmo se o Firestore ainda estiver sem regras.
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadCustomCommunities() async {
    final localCommunities = await _localService.loadCustomCommunities();

    if (!isUsingFirebase) {
      return localCommunities;
    }

    try {
      final cloudCommunities = await _firebaseService.loadCustomCommunities();
      final mergedCommunities = <Map<String, dynamic>>[];
      final usedIds = <String>{};

      for (final community in [...cloudCommunities, ...localCommunities]) {
        final id = community['id']?.toString();
        if (id == null || usedIds.contains(id)) continue;

        usedIds.add(id);
        mergedCommunities.add(community);
      }

      return mergedCommunities;
    } catch (_) {
      return localCommunities;
    }
  }

  Future<void> saveCustomCommunity(Map<String, dynamic> community) async {
    await _localService.saveCustomCommunity(community);

    if (isUsingFirebase) {
      try {
        await _firebaseService.saveCustomCommunity(community);
      } catch (_) {
        // A comunidade continua salva localmente se o Firestore negar escrita.
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadAIChatHistory(String userId) async {
    final localMessages = await _localService.loadAIChatHistory(userId);

    if (!isUsingFirebase) {
      return localMessages;
    }

    try {
      final cloudMessages = await _firebaseService.loadAIChatHistory(userId);
      return cloudMessages.isNotEmpty ? cloudMessages : localMessages;
    } catch (_) {
      return localMessages;
    }
  }

  Future<void> saveAIChatHistory(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    await _localService.saveAIChatHistory(userId, messages);

    if (isUsingFirebase) {
      try {
        await _firebaseService.saveAIChatHistory(userId, messages);
      } catch (_) {
        // O chat continua salvo localmente se o Firestore negar a escrita.
      }
    }
  }

  Future<void> clearAIChatHistory(String userId) async {
    await _localService.clearAIChatHistory(userId);

    if (isUsingFirebase) {
      try {
        await _firebaseService.clearAIChatHistory(userId);
      } catch (_) {
        // Mantem o fluxo local funcionando.
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadPostComments(String userId) async {
    final localComments = await _localService.loadPostComments(userId);

    if (!isUsingFirebase) {
      return localComments;
    }

    try {
      final cloudComments = await _firebaseService.loadPostComments();
      final mergedComments = <Map<String, dynamic>>[];
      final usedIds = <String>{};

      for (final comment in [...cloudComments, ...localComments]) {
        final id = comment['id']?.toString();
        if (id == null || usedIds.contains(id)) continue;

        usedIds.add(id);
        mergedComments.add(comment);
      }

      return mergedComments;
    } catch (_) {
      return localComments;
    }
  }

  Future<void> savePostComment(
    String userId,
    Map<String, dynamic> comment,
  ) async {
    await _localService.savePostComment(userId, comment);

    if (isUsingFirebase) {
      try {
        await _firebaseService.savePostComment(comment);
      } catch (_) {
        // O comentário fica salvo localmente se o Firestore negar a escrita.
      }
    }
  }

  String _firebaseMissingMessage() {
    final details = FirebaseBackendService.initializationError;
    if (details == null || details.isEmpty) {
      return 'Firebase não foi configurado neste build publicado. Gere o build usando scripts/build_web_from_env.ps1 e publique novamente.';
    }

    return 'Firebase não iniciou neste build publicado: $details';
  }
}
