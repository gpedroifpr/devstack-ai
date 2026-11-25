import 'package:flutter/foundation.dart';
import '../models/post_update.dart';

import 'firebase_backend_service.dart';
import 'local_database_service.dart';

export 'local_database_service.dart' show AuthResult, LocalAuthUser;

class AppDatabaseService {
  final LocalDatabaseService _localService = LocalDatabaseService();
  final FirebaseBackendService _firebaseService = FirebaseBackendService();

  bool get isUsingFirebase => FirebaseBackendService.isInitialized;

  Future<void> syncPublicAvatar() async {
    if (isUsingFirebase) await _firebaseService.syncPublicAvatar();
  }

  Stream<String?> watchAuthorPhoto(String userId) {
    if (isUsingFirebase) return _firebaseService.watchAuthorPhoto(userId);
    return _localService.loadAuthorPhoto(userId).asStream();
  }

  Future<void> sendPasswordReset(String email) async {
    if (!isUsingFirebase) {
      throw StateError(
        'A recuperação de senha precisa de conexão com o Firebase.',
      );
    }
    await _firebaseService.sendPasswordReset(email);
  }

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

  Future<AuthResult> signInWithGoogle() async {
    if (!kIsWeb) {
      return AuthResult.failure('Use o site para entrar com Google.');
    }
    if (!isUsingFirebase) return AuthResult.failure(_firebaseMissingMessage());
    return _firebaseService.signInWithGoogle();
  }

  Future<void> signOut() async {
    if (isUsingFirebase) {
      await _firebaseService.signOut();
      return;
    }

    await _localService.signOut();
  }

  Future<void> updateProfilePhoto(String photoBase64) async {
    if (isUsingFirebase) {
      await _firebaseService.updateProfilePhoto(photoBase64);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    final user = await _localService.loadCurrentUser();
    if (user == null) throw StateError('Entre novamente para trocar sua foto.');
    await _localService.updateCurrentUserProfile(
      name: user.name,
      username: user.username,
      photoBase64: photoBase64,
    );
  }

  Future<LocalAuthUser?> updateCurrentUserProfile({
    required String name,
    required String username,
    String? photoBase64,
  }) async {
    if (isUsingFirebase) {
      return _firebaseService.updateCurrentUserProfile(
        name: name,
        username: username,
        photoBase64: photoBase64,
      );
    }

    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    return _localService.updateCurrentUserProfile(
      name: name,
      username: username,
      photoBase64: photoBase64,
    );
  }

  Future<Set<String>> loadLikedPostIds() {
    return _localService.loadLikedPostIds();
  }

  Future<Set<String>> loadFavoritedPostIds(String userId) {
    if (isUsingFirebase) return _firebaseService.loadFavoritedPostIds();
    return _localService.loadFavoritedPostIds(userId);
  }

  Future<void> savePostLike(String postId, bool isLiked) {
    return _localService.savePostLike(postId, isLiked);
  }

  Future<void> savePostFavorite(
    String userId,
    String postId,
    bool isFavorited,
  ) {
    if (isUsingFirebase) {
      return _firebaseService.savePostFavorite(postId, isFavorited);
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    return _localService.savePostFavorite(userId, postId, isFavorited);
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
    if (isUsingFirebase) {
      await _firebaseService.saveUserPost(post);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    await _localService.saveUserPost(post);
  }

  Future<void> updateUserPost(String userId, String postId, PostUpdate update) {
    if (isUsingFirebase) return _firebaseService.updateUserPost(postId, update);
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    return _localService.updateUserPost(userId, postId, update);
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
    if (isUsingFirebase) {
      await _firebaseService.saveCustomCommunity(community);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    await _localService.saveCustomCommunity(community);
    await _localService.setCommunityFollowed(
      community['ownerId'].toString(),
      community['id'].toString(),
      true,
    );
  }

  Future<Set<String>> loadFollowedCommunityIds(String userId) {
    if (isUsingFirebase) return _firebaseService.loadFollowedCommunityIds();
    return _localService.loadFollowedCommunityIds(userId);
  }

  Future<void> setCommunityFollowed(
    String userId,
    String communityId,
    bool followed,
  ) {
    if (isUsingFirebase) {
      return _firebaseService.setCommunityFollowed(communityId, followed);
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    return _localService.setCommunityFollowed(userId, communityId, followed);
  }

  Future<List<Map<String, dynamic>>> loadAIChatHistory(String userId) async {
    if (isUsingFirebase) return _firebaseService.loadAIChatHistory(userId);
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    return _localService.loadAIChatHistory(userId);
  }

  Future<void> saveAIChatHistory(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (isUsingFirebase) {
      await _firebaseService.saveAIChatHistory(userId, messages);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    await _localService.saveAIChatHistory(userId, messages);
  }

  Future<void> clearAIChatHistory(String userId) async {
    if (isUsingFirebase) {
      await _firebaseService.clearAIChatHistory(userId);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    await _localService.clearAIChatHistory(userId);
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
    if (isUsingFirebase) {
      await _firebaseService.savePostComment(comment);
      return;
    }
    if (kReleaseMode) throw StateError(_firebaseMissingMessage());
    await _localService.savePostComment(userId, comment);
  }

  String _firebaseMissingMessage() {
    final details = FirebaseBackendService.initializationError;
    if (details == null || details.isEmpty) {
      return 'Firebase não foi configurado neste build publicado. Gere o build usando scripts/build_web_from_env.ps1 e publique novamente.';
    }

    return 'Firebase não iniciou neste build publicado: $details';
  }
}
