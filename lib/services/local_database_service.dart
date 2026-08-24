import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? photoBase64;
  final bool isGuest;

  LocalAuthUser({
    required this.id,
    required this.name,
    String? username,
    required this.email,
    this.photoBase64,
    this.isGuest = false,
  }) : username =
           username ??
           '@${name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

  factory LocalAuthUser.guest() {
    return LocalAuthUser(
      id: 'guest',
      name: 'Visitante',
      username: '@visitante',
      email: 'visitante@devstack.local',
      isGuest: true,
    );
  }

  factory LocalAuthUser.fromJson(Map<String, dynamic> json) {
    return LocalAuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username']?.toString(),
      email: json['email'] as String,
      photoBase64: json['photoBase64']?.toString(),
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'photoBase64': photoBase64,
      'isGuest': isGuest,
    };
  }
}

class AuthResult {
  final LocalAuthUser? user;
  final String? error;

  AuthResult.success(this.user) : error = null;

  AuthResult.failure(this.error) : user = null;

  bool get isSuccess => user != null;
}

class LocalDatabaseService {
  static const _likedPostsKey = 'liked_post_ids';
  static const _favoritedPostsKey = 'favorited_post_ids';
  static const _searchHistoryKey = 'search_history';
  static const _usersKey = 'registered_users';
  static const _currentUserKey = 'current_user_id';
  static const _userPostsKey = 'user_posts';
  static const _customCommunitiesKey = 'custom_communities';
  static const _aiChatHistoryPrefix = 'ai_chat_history';
  static const _postCommentsPrefix = 'post_comments';

  Future<LocalAuthUser?> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString(_currentUserKey);
    if (currentUserId == null) return null;

    final users = await _loadUsers();
    Map<String, dynamic>? userData;

    for (final user in users) {
      if (user['id'] == currentUserId) {
        userData = user;
        break;
      }
    }

    if (userData == null) return null;
    return LocalAuthUser.fromJson(userData);
  }

  Future<AuthResult> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    if (normalizedName.length < 3) {
      return AuthResult.failure('Informe um nome com pelo menos 3 caracteres.');
    }
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      return AuthResult.failure('Informe um e-mail válido.');
    }
    if (normalizedPassword.length < 6) {
      return AuthResult.failure('A senha precisa ter pelo menos 6 caracteres.');
    }

    final users = await _loadUsers();
    final emailAlreadyExists = users.any(
      (user) => user['email'] == normalizedEmail,
    );

    if (emailAlreadyExists) {
      return AuthResult.failure('Já existe uma conta com esse e-mail.');
    }

    final user = LocalAuthUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: normalizedName,
      email: normalizedEmail,
    );

    users.add({...user.toJson(), 'password': normalizedPassword});

    await _saveUsers(users);
    await _saveCurrentUserId(user.id);

    return AuthResult.success(user);
  }

  Future<LocalAuthUser?> updateCurrentUserProfile({
    required String name,
    required String username,
    String? photoBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString(_currentUserKey);
    if (currentUserId == null) return null;

    final normalizedName = name.trim();
    final normalizedUsername = username.trim().startsWith('@')
        ? username.trim()
        : '@${username.trim()}';

    if (normalizedName.length < 3 || normalizedUsername.length < 2) {
      return null;
    }

    final users = await _loadUsers();
    for (var i = 0; i < users.length; i++) {
      if (users[i]['id'] == currentUserId) {
        users[i] = {
          ...users[i],
          'name': normalizedName,
          'username': normalizedUsername,
          'photoBase64': photoBase64,
        };
        await _saveUsers(users);
        return LocalAuthUser.fromJson(users[i]);
      }
    }

    return null;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    final users = await _loadUsers();
    Map<String, dynamic>? userData;

    for (final user in users) {
      if (user['email'] == normalizedEmail &&
          user['password'] == normalizedPassword) {
        userData = user;
        break;
      }
    }

    if (userData == null) {
      return AuthResult.failure('E-mail ou senha incorretos.');
    }

    final user = LocalAuthUser.fromJson(userData);
    await _saveCurrentUserId(user.id);

    return AuthResult.success(user);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  Future<Set<String>> loadLikedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_likedPostsKey) ?? []).toSet();
  }

  Future<Set<String>> loadFavoritedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritedPostsKey) ?? []).toSet();
  }

  Future<void> savePostLike(String postId, bool isLiked) async {
    final prefs = await SharedPreferences.getInstance();
    final likedPostIds = (prefs.getStringList(_likedPostsKey) ?? []).toSet();

    if (isLiked) {
      likedPostIds.add(postId);
    } else {
      likedPostIds.remove(postId);
    }

    await prefs.setStringList(_likedPostsKey, likedPostIds.toList());
  }

  Future<void> savePostFavorite(String postId, bool isFavorited) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritedPostIds = (prefs.getStringList(_favoritedPostsKey) ?? [])
        .toSet();

    if (isFavorited) {
      favoritedPostIds.add(postId);
    } else {
      favoritedPostIds.remove(postId);
    }

    await prefs.setStringList(_favoritedPostsKey, favoritedPostIds.toList());
  }

  Future<List<String>> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  Future<List<String>> saveSearchQuery(
    String query,
    List<String> currentHistory,
  ) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return currentHistory;

    final prefs = await SharedPreferences.getInstance();
    final updatedHistory = [...currentHistory];

    updatedHistory.removeWhere(
      (item) => item.toLowerCase() == normalizedQuery.toLowerCase(),
    );
    updatedHistory.insert(0, normalizedQuery);

    final limitedHistory = updatedHistory.take(10).toList();
    await prefs.setStringList(_searchHistoryKey, limitedHistory);

    return limitedHistory;
  }

  Future<List<Map<String, dynamic>>> loadUserPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPosts = prefs.getStringList(_userPostsKey) ?? [];

    return rawPosts
        .map((rawPost) => jsonDecode(rawPost) as Map<String, dynamic>)
        .toList();
  }

  Future<void> saveUserPost(Map<String, dynamic> post) async {
    final prefs = await SharedPreferences.getInstance();
    final posts = await loadUserPosts();

    posts.insert(0, post);

    final rawPosts = posts.map((savedPost) => jsonEncode(savedPost)).toList();
    await prefs.setStringList(_userPostsKey, rawPosts);
  }

  Future<List<Map<String, dynamic>>> loadCustomCommunities() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCommunities = prefs.getStringList(_customCommunitiesKey) ?? [];

    return rawCommunities
        .map((rawCommunity) => jsonDecode(rawCommunity) as Map<String, dynamic>)
        .toList();
  }

  Future<void> saveCustomCommunity(Map<String, dynamic> community) async {
    final prefs = await SharedPreferences.getInstance();
    final communities = await loadCustomCommunities();

    communities.insert(0, community);

    final rawCommunities = communities
        .map((savedCommunity) => jsonEncode(savedCommunity))
        .toList();
    await prefs.setStringList(_customCommunitiesKey, rawCommunities);
  }

  Future<List<Map<String, dynamic>>> loadAIChatHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMessages = prefs.getStringList(_aiChatHistoryKey(userId)) ?? [];

    return rawMessages
        .map((rawMessage) => jsonDecode(rawMessage) as Map<String, dynamic>)
        .toList();
  }

  Future<void> saveAIChatHistory(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final limitedMessages = messages.length > 80
        ? messages.sublist(messages.length - 80)
        : messages;
    final rawMessages = limitedMessages
        .map((message) => jsonEncode(message))
        .toList();

    await prefs.setStringList(_aiChatHistoryKey(userId), rawMessages);
  }

  Future<void> clearAIChatHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aiChatHistoryKey(userId));
  }

  Future<List<Map<String, dynamic>>> loadPostComments(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawComments =
        prefs.getStringList(_postCommentsKey(userId)) ?? const [];

    return rawComments
        .map((rawComment) => jsonDecode(rawComment) as Map<String, dynamic>)
        .toList();
  }

  Future<void> savePostComment(
    String userId,
    Map<String, dynamic> comment,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final comments = await loadPostComments(userId);

    comments.insert(0, comment);

    final rawComments = comments
        .map((savedComment) => jsonEncode(savedComment))
        .toList();
    await prefs.setStringList(_postCommentsKey(userId), rawComments);
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getStringList(_usersKey) ?? [];

    return rawUsers
        .map((rawUser) => jsonDecode(rawUser) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _saveUsers(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = users.map((user) => jsonEncode(user)).toList();
    await prefs.setStringList(_usersKey, rawUsers);
  }

  Future<void> _saveCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
  }

  String _aiChatHistoryKey(String userId) {
    return '${_aiChatHistoryPrefix}_$userId';
  }

  String _postCommentsKey(String userId) {
    return '${_postCommentsPrefix}_$userId';
  }
}
