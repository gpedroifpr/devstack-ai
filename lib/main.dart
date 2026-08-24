import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'screens/auth_screen.dart';
import 'services/app_database_service.dart';
import 'services/clipboard_image_paste_service.dart';
import 'services/firebase_backend_service.dart';

void main() async {
  // Carregar variáveis de ambiente do arquivo .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Aviso: Arquivo .env não encontrado. Usando variáveis padrão.');
  }

  await FirebaseBackendService.initializeFromEnv();

  runApp(const DevStackApp());
}

class DevStackApp extends StatelessWidget {
  const DevStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1215),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AppDatabaseService _databaseService = AppDatabaseService();
  LocalAuthUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _databaseService.loadCurrentUser();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    await _databaseService.signOut();

    if (!mounted) return;

    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return AuthScreen(
        onAuthenticated: (user) {
          setState(() {
            _currentUser = user;
          });
        },
      );
    }

    return FeedScreen(currentUser: _currentUser!, onSignOut: _signOut);
  }
}

// ============= MODELOS DE DADOS =============

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AIContextAttachment> attachments;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class AIContextAttachment {
  final String type;
  final String title;
  final String content;
  final IconData icon;
  final Uint8List? bytes;
  final String? mimeType;
  final String? fileName;

  AIContextAttachment({
    required this.type,
    required this.title,
    required this.content,
    required this.icon,
    this.bytes,
    this.mimeType,
    this.fileName,
  });

  bool get hasFile => bytes != null && mimeType != null;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
}

class Post {
  final String id;
  final String username;
  final String userHandle;
  final String title;
  final String description;
  final String code;
  final List<String> tags;
  final int likes;
  final int comments;
  final String timeAgo;
  final bool isQuestion;
  final String? communityId;
  final String? communityName;
  bool isLiked;
  bool isFavorited;

  Post({
    required this.id,
    required this.username,
    required this.userHandle,
    required this.title,
    required this.description,
    required this.code,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    this.isQuestion = false,
    this.communityId,
    this.communityName,
    this.isLiked = false,
    this.isFavorited = false,
  });
}

class PostComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      postId: json['postId']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Usuário DevStack',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAtLocal']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'body': body,
      'createdAtLocal': createdAt.toIso8601String(),
    };
  }
}

class Notification {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final String type;
  bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.type,
    this.isRead = false,
  });
}

class Community {
  final String id;
  final String name;
  final String description;
  final int members;
  final String icon;
  final bool isCustom;
  bool isFollowed;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.icon,
    this.isCustom = false,
    this.isFollowed = false,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Comunidade',
      description: json['description']?.toString() ?? '',
      members: int.tryParse(json['members']?.toString() ?? '') ?? 1,
      icon: json['icon']?.toString() ?? '💬',
      isCustom: json['isCustom'] as bool? ?? true,
      isFollowed: json['isFollowed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'members': members,
      'icon': icon,
      'isCustom': isCustom,
      'isFollowed': isFollowed,
    };
  }
}

class FeedScreen extends StatefulWidget {
  final LocalAuthUser currentUser;
  final VoidCallback onSignOut;

  const FeedScreen({
    super.key,
    required this.currentUser,
    required this.onSignOut,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _selectedTagIndex = 0;
  bool _isShowingSearch = false;
  bool _isShowingNotifications = false;
  late LocalAuthUser _activeUser;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  final List<ChatMessage> _chatMessages = [];
  late List<Post> _allPosts = [];
  late List<Post> _filteredPosts = [];
  late List<Notification> _notifications = [];
  late List<Community> _communities = [];
  late List<String> _searchHistory = [];
  late Map<String, List<PostComment>> _postComments = {};
  Community? _selectedCommunity;
  Post? _selectedPost;
  String? _selectedProfileSection;
  final AppDatabaseService _databaseService = AppDatabaseService();

  bool _isLoadingAI = false;
  bool _aiRequestHasAttachments = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiMessageController = TextEditingController();
  final FocusNode _aiMessageFocusNode = FocusNode();
  final TextEditingController _aiContextTitleController =
      TextEditingController();
  final TextEditingController _aiContextContentController =
      TextEditingController();
  final TextEditingController _doubtTitleController = TextEditingController();
  final TextEditingController _doubtDescriptionController =
      TextEditingController();
  final TextEditingController _doubtCodeController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _communityNameController =
      TextEditingController();
  final TextEditingController _communityDescriptionController =
      TextEditingController();
  final TextEditingController _communityIconController = TextEditingController(
    text: '💬',
  );
  final List<AIContextAttachment> _aiContextAttachments = [];
  Object? _clipboardPasteSubscription;

  final Color primaryCyan = const Color(0xFF4EE2EC);
  final Color cardColor = const Color(0xFF162126);
  final List<String> tags = ['Todos', 'Flutter', 'AI', 'JavaScript', 'Python'];

  // Profile Controllers
  late TextEditingController _profileNameController;
  late TextEditingController _profileUsernameController;
  late TextEditingController _profileEmailController;
  late TextEditingController _profilePhoneController;
  late TextEditingController _profileCepController;
  late TextEditingController _profileRuaController;
  late TextEditingController _profileBairroController;
  late TextEditingController _profileCidadeController;
  late TextEditingController _profileEstadoController;
  late TextEditingController _profileNumeroController;
  late TextEditingController _profileComplementoController;
  bool _cepLoading = false;
  String? _cepError;
  bool _profileEditing = false;

  @override
  void initState() {
    super.initState();
    _activeUser = widget.currentUser;
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );
    _transitionController.forward();

    _profileNameController = TextEditingController(text: _activeUser.name);
    _profileUsernameController = TextEditingController(
      text: _activeUser.username,
    );
    _profileEmailController = TextEditingController(text: _activeUser.email);
    _profilePhoneController = TextEditingController();
    _profileCepController = TextEditingController();
    _profileRuaController = TextEditingController();
    _profileBairroController = TextEditingController();
    _profileCidadeController = TextEditingController();
    _profileEstadoController = TextEditingController();
    _profileNumeroController = TextEditingController();
    _profileComplementoController = TextEditingController();
    _clipboardPasteSubscription = ClipboardImagePasteService.listen(
      _handlePastedImageAttachment,
    );

    _initializeData();
  }

  Future<void> _initializeData() async {
    final userPosts = await _loadUserPosts();
    _allPosts = [...userPosts, ..._generateSamplePosts()];
    await _applyLocalPostState();

    _filteredPosts = _allPosts;
    _notifications = _generateSampleNotifications();
    final customCommunities = await _loadCustomCommunities();
    _communities = [...customCommunities, ..._generateSampleCommunities()];
    _searchHistory = await _databaseService.loadSearchHistory();
    _postComments = await _loadPostComments();
    _mergeSampleComments();
    await _loadAIChatHistory();
    setState(() {});
  }

  Future<void> _refreshFeedFromDatabase() async {
    final userPosts = await _loadUserPosts();

    if (!mounted) return;

    _allPosts = [...userPosts, ..._generateSamplePosts()];
    await _applyLocalPostState();

    if (!mounted) return;

    setState(() {
      _selectedTagIndex = 0;
      _searchQuery = '';
      _searchController.clear();
      _filteredPosts = _allPosts;
    });
  }

  Future<void> _applyLocalPostState() async {
    final likedPostIds = await _databaseService.loadLikedPostIds();
    final favoritedPostIds = await _databaseService.loadFavoritedPostIds();

    for (final post in _allPosts) {
      post.isLiked = likedPostIds.contains(post.id);
      post.isFavorited = favoritedPostIds.contains(post.id);
    }
  }

  Future<void> _loadAIChatHistory() async {
    final savedMessages = await _databaseService.loadAIChatHistory(
      _activeUser.id,
    );

    if (!mounted || savedMessages.isEmpty) return;

    _chatMessages
      ..clear()
      ..addAll(savedMessages.map(ChatMessage.fromJson));
  }

  Future<void> _saveAIChatHistory() {
    return _databaseService.saveAIChatHistory(
      _activeUser.id,
      _chatMessages.map((message) => message.toJson()).toList(),
    );
  }

  Future<void> _clearAIChatHistory() async {
    setState(() {
      _chatMessages.clear();
      _aiContextAttachments.clear();
    });

    await _databaseService.clearAIChatHistory(_activeUser.id);
  }

  int get _unreadNotificationCount {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  Future<Map<String, List<PostComment>>> _loadPostComments() async {
    final savedComments = await _databaseService.loadPostComments(
      _activeUser.id,
    );
    final groupedComments = <String, List<PostComment>>{};

    for (final rawComment in savedComments) {
      final comment = PostComment.fromJson(rawComment);
      if (comment.postId.isEmpty || comment.body.trim().isEmpty) continue;

      groupedComments.putIfAbsent(comment.postId, () => []).add(comment);
    }

    for (final comments in groupedComments.values) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return groupedComments;
  }

  List<PostComment> _commentsForPost(Post post) {
    return _postComments[post.id] ?? const [];
  }

  void _mergeSampleComments() {
    for (final comment in _generateSampleComments()) {
      final comments = _postComments.putIfAbsent(comment.postId, () => []);
      final alreadyExists = comments.any((saved) => saved.id == comment.id);

      if (!alreadyExists) {
        comments.add(comment);
      }
    }

    for (final comments in _postComments.values) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  List<PostComment> _generateSampleComments() {
    final now = DateTime.now();

    return [
      PostComment(
        id: 'sample-comment-1',
        postId: '1',
        authorId: 'sample-marina',
        authorName: 'Marina Lopes',
        body:
            'Uma boa saída é criar uma pasta screens para telas e services para integrações. Depois dá para separar models também.',
        createdAt: now.subtract(const Duration(minutes: 32)),
      ),
      PostComment(
        id: 'sample-comment-2',
        postId: '2',
        authorId: 'sample-rafael',
        authorName: 'Rafael Costa',
        body:
            'Esse exemplo ajuda bastante. Eu só adicionaria tratamento de erro com try/catch para chamadas externas.',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      PostComment(
        id: 'sample-comment-3',
        postId: '3',
        authorId: 'sample-equipe',
        authorName: 'Equipe DevStack',
        body:
            'Quando a dúvida vem com erro, trecho do código e objetivo esperado, a IA consegue responder muito melhor.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  int _visibleCommentCount(Post post) {
    return post.comments + _commentsForPost(post).length;
  }

  Future<void> _publishComment(Post post) async {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('comentar em publicações');
      return;
    }

    final body = _commentController.text.trim();
    if (body.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escreva um comentário um pouco mais completo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final comment = PostComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      postId: post.id,
      authorId: _activeUser.id,
      authorName: _activeUser.name,
      body: body,
      createdAt: DateTime.now(),
    );

    await _databaseService.savePostComment(_activeUser.id, comment.toJson());

    if (!mounted) return;

    setState(() {
      _postComments.putIfAbsent(post.id, () => []).insert(0, comment);
      _commentController.clear();
    });

    _addNotification(
      title: 'Comentário publicado',
      message: 'Você respondeu a discussão "${post.title}".',
      type: 'comment',
    );
  }

  Future<List<Post>> _loadUserPosts() async {
    final savedPosts = await _databaseService.loadUserPosts();

    return savedPosts.map((post) {
      return Post(
        id:
            post['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        username: post['username']?.toString() ?? _activeUser.name,
        userHandle: post['userHandle']?.toString() ?? _activeUser.username,
        title: post['title']?.toString() ?? 'Dúvida sem título',
        description: post['description']?.toString() ?? '',
        code: post['code']?.toString() ?? '',
        tags: (post['tags'] as List<dynamic>? ?? [])
            .map((tag) => tag.toString())
            .toList(),
        likes: (post['likes'] as num?)?.toInt() ?? 0,
        comments: (post['comments'] as num?)?.toInt() ?? 0,
        timeAgo: post['timeAgo']?.toString() ?? 'Agora',
        isQuestion: post['isQuestion'] as bool? ?? true,
        communityId: post['communityId']?.toString(),
        communityName: post['communityName']?.toString(),
      );
    }).toList();
  }

  List<Post> _generateSamplePosts() {
    return [
      Post(
        id: '1',
        username: 'Equipe DevStack',
        userHandle: '@devstack',
        title: 'Como organizar uma tela Flutter sem deixar tudo no main.dart?',
        description:
            'Uma dúvida comum no começo do projeto é separar telas, serviços e modelos sem quebrar o app.',
        code: 'lib/\n  main.dart\n  screens/\n  services/\n  models/',
        tags: ['Flutter', 'Arquitetura', 'AI'],
        likes: 38,
        comments: 7,
        timeAgo: 'Fixado',
        isQuestion: true,
      ),
      Post(
        id: '2',
        username: 'Marina Lopes',
        userHandle: '@marina.dev',
        title: 'Entendendo async/await com um exemplo simples',
        description:
            'Async/await ajuda a lidar com chamadas de API sem travar a interface do aplicativo.',
        code:
            'Future<void> carregarPosts() async {\n  final posts = await api.buscarPosts();\n  setState(() => lista = posts);\n}',
        tags: ['Flutter', 'Dart', 'Backend'],
        likes: 92,
        comments: 14,
        timeAgo: '2h',
      ),
      Post(
        id: '3',
        username: 'Rafael Costa',
        userHandle: '@rafa.front',
        title: 'Checklist antes de pedir ajuda para a IA',
        description:
            'Explique o erro, mande o trecho principal do código e diga o que você já tentou.',
        code: 'Erro:\nO que eu esperava:\nO que aconteceu:\nTrecho do código:',
        tags: ['AI', 'JavaScript', 'Estudo'],
        likes: 74,
        comments: 9,
        timeAgo: '4h',
      ),
      Post(
        id: '4',
        username: 'Bianca Souza',
        userHandle: '@bia.ai',
        title:
            'O que uma IA generativa pode fazer dentro de uma comunidade dev?',
        description:
            'Além de responder perguntas, ela pode resumir dúvidas, revisar código e sugerir próximos passos.',
        code:
            'Prompt útil:\n"Explique este erro como se eu estivesse aprendendo Flutter."',
        tags: ['AI', 'Python', 'ML'],
        likes: 128,
        comments: 21,
        timeAgo: '1d',
      ),
      Post(
        id: '5',
        username: 'Lucas Neri',
        userHandle: '@lucas.web',
        title: 'Diferença entre front-end, back-end e banco de dados',
        description:
            'Um resumo rápido para quem está começando a entender a estrutura de aplicações modernas.',
        code:
            'Front-end: interface\nBack-end: regras e APIs\nBanco: dados persistentes',
        tags: ['JavaScript', 'Backend', 'Estudo'],
        likes: 61,
        comments: 8,
        timeAgo: '2d',
      ),
    ];
  }

  List<Notification> _generateSampleNotifications() {
    return [
      Notification(
        id: '1',
        title: 'Bem-vindo ao DevStack AI',
        message: _activeUser.isGuest
            ? 'Você está explorando como visitante. Entre para salvar dúvidas e histórico.'
            : 'Seu feed, IA e comunidades já estão prontos para estudo.',
        timeAgo: '2 min',
        type: 'system',
      ),
      Notification(
        id: '2',
        title: 'Comunidade recomendada',
        message: 'A comunidade Flutter Brasil combina com seus interesses.',
        timeAgo: '15 min',
        type: 'follow',
      ),
      Notification(
        id: '3',
        title: 'Dica da IA',
        message:
            'Você pode colar mensagens de erro completas no chat para receber uma explicação melhor.',
        timeAgo: '1h',
        type: 'ai',
      ),
      Notification(
        id: '4',
        title: 'Publicação em destaque',
        message: 'Seu post sobre cadastro local recebeu novas curtidas.',
        timeAgo: '3h',
        type: 'trending',
      ),
    ];
  }

  void _addNotification({
    required String title,
    required String message,
    required String type,
  }) {
    setState(() {
      _notifications.insert(
        0,
        Notification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          message: message,
          timeAgo: 'Agora',
          type: type,
        ),
      );
    });
  }

  void _markAllNotificationsAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _handleNotificationTap(Notification notification) {
    setState(() {
      notification.isRead = true;
      _isShowingNotifications = false;
      _isShowingSearch = false;
      _selectedPost = null;

      switch (notification.type) {
        case 'community':
        case 'follow':
          _selectedIndex = 1;
          _selectedCommunity = _communities.isNotEmpty
              ? _communities.first
              : null;
          break;
        case 'ai':
          _selectedIndex = 3;
          break;
        default:
          _selectedIndex = 0;
          _selectedCommunity = null;
      }
    });
    _changeScreen();
  }

  List<Community> _generateSampleCommunities() {
    return [
      Community(
        id: '1',
        name: 'Flutter Brasil',
        description:
            'Dúvidas sobre widgets, rotas, estado, Firebase e publicação web.',
        members: 1840,
        icon: '📱',
      ),
      Community(
        id: '2',
        name: 'IA para Devs',
        description:
            'Prompts, Gemini API, revisão de código e automações para estudo.',
        members: 1260,
        icon: '✨',
      ),
      Community(
        id: '3',
        name: 'JavaScript & Web',
        description:
            'Front-end, APIs, integração com back-end e deploy de aplicações.',
        members: 2310,
        icon: '🌐',
      ),
      Community(
        id: '4',
        name: 'Banco de Dados',
        description:
            'Modelagem, Firebase, Supabase, SQL e persistência de dados.',
        members: 940,
        icon: '🗄️',
      ),
      Community(
        id: '5',
        name: 'Carreira e Projetos',
        description:
            'Portfólio, PFC, apresentação de projetos e organização de estudos.',
        members: 760,
        icon: '🚀',
      ),
    ];
  }

  Future<List<Community>> _loadCustomCommunities() async {
    final savedCommunities = await _databaseService.loadCustomCommunities();

    return savedCommunities
        .map(Community.fromJson)
        .where((community) => community.id.isNotEmpty)
        .toList();
  }

  Future<void> _addToSearchHistory(String query) async {
    final updatedHistory = await _databaseService.saveSearchQuery(
      query,
      _searchHistory,
    );
    setState(() {
      _searchHistory = updatedHistory;
    });
  }

  void _searchPosts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPosts = _allPosts;
      } else {
        _filteredPosts = _allPosts
            .where(
              (post) =>
                  post.title.toLowerCase().contains(query.toLowerCase()) ||
                  post.description.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  post.tags.any(
                    (tag) => tag.toLowerCase().contains(query.toLowerCase()),
                  ),
            )
            .toList();
      }
    });
  }

  Future<void> _togglePostLike(Post post) async {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('curtir publicações');
      return;
    }

    setState(() {
      post.isLiked = !post.isLiked;
    });

    await _databaseService.savePostLike(post.id, post.isLiked);
  }

  Future<void> _togglePostFavorite(Post post) async {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('salvar publicações');
      return;
    }

    setState(() {
      post.isFavorited = !post.isFavorited;
    });

    await _databaseService.savePostFavorite(post.id, post.isFavorited);
  }

  void _toggleCommunityFollow(Community community) {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('seguir comunidades');
      return;
    }

    setState(() {
      community.isFollowed = !community.isFollowed;
    });
  }

  void _showCreateDoubtDialog({Community? community}) {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('publicar uma dúvida');
      return;
    }

    final selectedTags = <String>{
      if (community != null)
        ..._tagsForCommunity(
          community,
        ).where((tag) => tags.contains(tag)).take(2),
    };
    if (selectedTags.isEmpty) selectedTags.add('AI');
    _doubtTitleController.clear();
    _doubtDescriptionController.clear();
    _doubtCodeController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(18),
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryCyan.withValues(alpha: 0.25),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: primaryCyan.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.help_outline, color: primaryCyan),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nova dúvida',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Organize seu problema antes de pedir ajuda.',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (community != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: primaryCyan.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryCyan.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                community.icon,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Publicando em ${community.name}',
                                  style: TextStyle(
                                    color: Colors.grey.shade200,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildDialogField(
                        controller: _doubtTitleController,
                        label: 'Título da dúvida',
                        hint: 'Ex: Como resolver esse erro no Flutter?',
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        controller: _doubtDescriptionController,
                        label: 'Descrição',
                        hint: 'Explique o que você tentou e onde travou.',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        controller: _doubtCodeController,
                        label: 'Código ou erro (opcional)',
                        hint:
                            'Cole aqui um trecho de código, stack trace ou mensagem de erro.',
                        maxLines: 5,
                        monospace: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tags',
                        style: TextStyle(
                          color: primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.where((tag) => tag != 'Todos').map((
                          tag,
                        ) {
                          final isSelected = selectedTags.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedTags.remove(tag);
                                } else {
                                  selectedTags.add(tag);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryCyan.withValues(alpha: 0.18)
                                    : const Color(0xFF0F171A),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryCyan
                                      : Colors.white12,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: isSelected ? primaryCyan : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade300,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryCyan,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => _createDoubtPost(
                                selectedTags.toList(),
                                community: community,
                              ),
                              icon: const Icon(Icons.publish),
                              label: const Text('Publicar dúvida'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAccountRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: 430,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryCyan.withValues(alpha: 0.22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryCyan.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.lock_outline, color: primaryCyan),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Conta necessária',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Você pode explorar o DevStack AI como visitante, usar o chat com IA e navegar pelo feed. Para $action, crie uma conta ou entre com seu e-mail.',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade300,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Agora não'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSignOut();
                        },
                        child: const Text(
                          'Criar conta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool monospace = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryCyan,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D171B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              color: Colors.white,
              fontFamily: monospace ? GoogleFonts.firaCode().fontFamily : null,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createDoubtPost(
    List<String> selectedTags, {
    Community? community,
  }) async {
    final title = _doubtTitleController.text.trim();
    final description = _doubtDescriptionController.text.trim();
    final code = _doubtCodeController.text.trim();

    if (title.length < 6 || description.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha um título e uma descrição um pouco mais completos.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final post = Post(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      username: _activeUser.name,
      userHandle: _activeUser.username,
      title: title,
      description: description,
      code: code,
      tags: selectedTags.isEmpty ? ['AI'] : selectedTags,
      likes: 0,
      comments: 0,
      timeAgo: 'Agora',
      isQuestion: true,
      communityId: community?.id,
      communityName: community?.name,
    );

    await _databaseService.saveUserPost({
      'id': post.id,
      'username': post.username,
      'userHandle': post.userHandle,
      'title': post.title,
      'description': post.description,
      'code': post.code,
      'tags': post.tags,
      'likes': post.likes,
      'comments': post.comments,
      'timeAgo': post.timeAgo,
      'isQuestion': post.isQuestion,
      'communityId': post.communityId,
      'communityName': post.communityName,
      'authorId': _activeUser.id,
      'authorEmail': _activeUser.email,
      'createdAtLocal': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;

    setState(() {
      _allPosts.insert(0, post);
      _filteredPosts = _allPosts;
      _selectedTagIndex = 0;
      _isShowingSearch = false;
      _isShowingNotifications = false;
    });

    _addNotification(
      title: 'Dúvida publicada',
      message: community == null
          ? 'Sua dúvida entrou no feed e já pode ser enviada para a IA.'
          : 'Sua dúvida foi publicada em ${community.name}.',
      type: community == null ? 'comment' : 'community',
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Dúvida publicada no feed.'),
        backgroundColor: primaryCyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    ClipboardImagePasteService.cancel(_clipboardPasteSubscription);
    _transitionController.dispose();
    _profileNameController.dispose();
    _profileEmailController.dispose();
    _profilePhoneController.dispose();
    _profileCepController.dispose();
    _profileRuaController.dispose();
    _profileBairroController.dispose();
    _profileCidadeController.dispose();
    _profileEstadoController.dispose();
    _profileNumeroController.dispose();
    _profileComplementoController.dispose();
    _searchController.dispose();
    _aiMessageController.dispose();
    _aiMessageFocusNode.dispose();
    _aiContextTitleController.dispose();
    _aiContextContentController.dispose();
    _doubtTitleController.dispose();
    _doubtDescriptionController.dispose();
    _doubtCodeController.dispose();
    _commentController.dispose();
    _communityNameController.dispose();
    _communityDescriptionController.dispose();
    _communityIconController.dispose();
    _profileUsernameController.dispose();
    super.dispose();
  }

  void _changeScreen() {
    _transitionController.reset();
    _transitionController.forward();
  }

  List<Post> get _feedPosts {
    if (_selectedTagIndex == 0) return _allPosts;

    final selectedTag = tags[_selectedTagIndex].toLowerCase();
    return _allPosts.where((post) {
      return post.tags.any((tag) => tag.toLowerCase() == selectedTag);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedPost == null) _buildHeader(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
            if (_selectedIndex != 3 && _selectedPost == null)
              _buildFloatingAskButton(),
          ],
        ),
      ),
      bottomNavigationBar: _selectedPost == null ? _buildBottomNav() : null,
    );
  }

  Widget _buildContent() {
    if (_selectedPost != null) {
      return _buildPostDetailContent(_selectedPost!);
    }

    if (_isShowingSearch) {
      return _buildSearchContent();
    }
    if (_isShowingNotifications) {
      return _buildNotificationsContent();
    }

    switch (_selectedIndex) {
      case 0:
        return _buildFeedContent();
      case 1:
        return _buildCommunitiesContent();
      case 2:
        return _buildProfileContent();
      case 3:
        return _buildAIConversationContent();
      default:
        return _buildFeedContent();
    }
  }

  // ============= FEED CONTENT =============

  Widget _buildFeedContent() {
    final feedPosts = _feedPosts;
    final selectedTag = tags[_selectedTagIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeHero(feedPosts.length, selectedTag),
        if (_activeUser.isGuest) _buildGuestHomePrompt(),
        _buildTagsRow(),
        Expanded(
          child: RefreshIndicator(
            color: primaryCyan,
            backgroundColor: cardColor,
            onRefresh: _refreshFeedFromDatabase,
            child: feedPosts.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(14),
                    children: [_buildEmptyFeedState(selectedTag)],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: feedPosts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == feedPosts.length) {
                        return const SizedBox(height: 80);
                      }
                      return _buildPostCardWidget(feedPosts[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeHero(int postCount, String selectedTag) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: const Color(0xFF10191D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, ${_activeUser.name.split(' ').first}',
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _activeUser.isGuest
                        ? 'Visitante • feed e IA liberados'
                        : selectedTag == 'Todos'
                        ? '$postCount posts • dúvidas e soluções'
                        : '$postCount posts em $selectedTag',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Atualizar feed',
              onPressed: _refreshFeedFromDatabase,
              icon: Icon(Icons.sync_rounded, color: primaryCyan, size: 20),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filled(
                tooltip: 'Criar dúvida',
                style: IconButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () => _showCreateDoubtDialog(),
                icon: const Icon(Icons.add_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestHomePrompt() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
        decoration: BoxDecoration(
          color: primaryCyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryCyan.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_open_rounded, color: primaryCyan, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Entre para publicar dúvidas e salvar seu progresso.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade200, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: widget.onSignOut,
              style: TextButton.styleFrom(
                foregroundColor: primaryCyan,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeedState(String selectedTag) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, color: primaryCyan, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Nenhum post encontrado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Ainda não há publicações em $selectedTag.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ============= SEARCH CONTENT =============

  Widget _buildSearchContent() {
    final matchingCommunities = _searchQuery.trim().isEmpty
        ? <Community>[]
        : _communities.where((community) {
            final query = _searchQuery.toLowerCase();
            return community.name.toLowerCase().contains(query) ||
                community.description.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchPosts,
            onSubmitted: (query) {
              _addToSearchHistory(query);
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Procurar posts, tags ou usuários...',
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: primaryCyan),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _searchPosts('');
                      },
                      child: Icon(Icons.close, color: primaryCyan),
                    )
                  : null,
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore o DevStack',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Busque por erro, linguagem, usuário, comunidade ou peça ajuda para a IA.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSearchActionGrid(),
                        const SizedBox(height: 18),
                        Text(
                          'Tags rápidas',
                          style: TextStyle(
                            color: primaryCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags
                              .where((tag) => tag != 'Todos')
                              .map(_buildSearchChip)
                              .toList(),
                        ),
                        const SizedBox(height: 18),
                        if (_searchHistory.isNotEmpty) ...[
                          Text(
                            'Histórico de buscas',
                            style: TextStyle(
                              color: primaryCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _searchHistory
                                .map(
                                  (query) => GestureDetector(
                                    onTap: () {
                                      _searchController.text = query;
                                      _searchPosts(query);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: primaryCyan.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        query,
                                        style: TextStyle(
                                          color: primaryCyan,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_filteredPosts.length + matchingCommunities.length} resultado(s)',
                            style: TextStyle(
                              color: primaryCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _addToSearchHistory(_searchQuery);
                            _sendQuestionToAI(
                              'Procurei por "$_searchQuery" no DevStack AI. Me ajude a entender esse tema e indique próximos passos.',
                              displayText: 'Me ajude com: $_searchQuery',
                            );
                          },
                          icon: const Icon(Icons.psychology, size: 16),
                          label: const Text('Perguntar à IA'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (matchingCommunities.isNotEmpty) ...[
                      Text(
                        'Comunidades',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...matchingCommunities.map(_buildSearchCommunityResult),
                      const SizedBox(height: 14),
                    ],
                    if (_filteredPosts.isNotEmpty) ...[
                      Text(
                        'Posts',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._filteredPosts.map(_buildPostCardWidget),
                    ],
                    if (_filteredPosts.isEmpty && matchingCommunities.isEmpty)
                      _buildSearchEmptyState(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSearchActionGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchActionCard(
            icon: Icons.edit_note_rounded,
            title: 'Criar dúvida',
            subtitle: 'Publique um problema no feed',
            onTap: () => _showCreateDoubtDialog(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSearchActionCard(
            icon: Icons.psychology_alt_outlined,
            title: 'Perguntar à IA',
            subtitle: 'Explique erro, código ou imagem',
            onTap: () {
              setState(() {
                _selectedIndex = 3;
                _isShowingSearch = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryCyan, size: 23),
            const SizedBox(height: 18),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchChip(String query) {
    return GestureDetector(
      onTap: () {
        _searchController.text = query;
        _searchPosts(query);
        _addToSearchHistory(query);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF10191D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
        ),
        child: Text(
          query,
          style: TextStyle(color: Colors.grey.shade200, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSearchCommunityResult(Community community) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = 1;
          _selectedCommunity = community;
          _isShowingSearch = false;
        });
        _addToSearchHistory(_searchQuery);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10191D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Text(community.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${community.members} membros',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: primaryCyan, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: primaryCyan, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Nada encontrado',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            'Tente uma tag, uma linguagem ou use a IA para transformar sua busca em uma dúvida.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============= NOTIFICATIONS CONTENT =============

  Widget _buildNotificationsContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificações',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _unreadNotificationCount == 0
                        ? 'Tudo lido por enquanto.'
                        : 'Você tem $_unreadNotificationCount novidade(s).',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _unreadNotificationCount == 0
                  ? null
                  : _markAllNotificationsAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 17),
              label: const Text('Ler tudo'),
              style: TextButton.styleFrom(foregroundColor: primaryCyan),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_notifications.isEmpty)
          _buildEmptyFeedState('notificações')
        else
          ..._notifications.map(_buildNotificationCard),
      ],
    );
  }

  Widget _buildNotificationCard(Notification notif) {
    return GestureDetector(
      onTap: () => _handleNotificationTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? const Color(0xFF10191D) : cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: notif.isRead
                ? Colors.white.withValues(alpha: 0.06)
                : primaryCyan.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryCyan.withValues(alpha: notif.isRead ? 0.1 : 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _getNotificationIcon(notif.type),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: primaryCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.timeAgo,
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Icon _getNotificationIcon(String type) {
    switch (type) {
      case 'comment':
        return Icon(Icons.comment, color: primaryCyan);
      case 'follow':
        return Icon(Icons.person_add, color: primaryCyan);
      case 'community':
        return Icon(Icons.people, color: primaryCyan);
      case 'trending':
        return Icon(Icons.trending_up, color: primaryCyan);
      case 'ai':
        return Icon(Icons.psychology_alt_outlined, color: primaryCyan);
      case 'system':
        return Icon(Icons.auto_awesome, color: primaryCyan);
      default:
        return Icon(Icons.notifications, color: primaryCyan);
    }
  }

  // ============= COMMUNITIES CONTENT =============

  Widget _buildCommunitiesContent() {
    if (_selectedCommunity != null) {
      return _buildCommunityDetailContent(_selectedCommunity!);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comunidades',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Criar comunidade',
              style: IconButton.styleFrom(
                backgroundColor: primaryCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showCreateCommunityDialog,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Escolha espaços para acompanhar dúvidas, projetos e conteúdos por área.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_alt_outlined, color: primaryCyan, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_communities.where((community) => community.isFollowed).length} comunidades seguidas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_communities.length} disponíveis',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._communities.map(_buildCommunityCard),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showCreateCommunityDialog() {
    if (_activeUser.isGuest) {
      _showAccountRequiredDialog('criar comunidades');
      return;
    }

    _communityNameController.clear();
    _communityDescriptionController.clear();
    _communityIconController.text = '💬';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryCyan.withValues(alpha: 0.22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primaryCyan.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.groups_2_rounded, color: primaryCyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Criar comunidade',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Monte um espaço para discutir um tema do projeto.',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildProfileTextField(
                    'Ícone',
                    _communityIconController,
                    Icons.emoji_emotions_outlined,
                    enabled: true,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileTextField(
                    'Nome da comunidade',
                    _communityNameController,
                    Icons.people_outline,
                    enabled: true,
                  ),
                  const SizedBox(height: 12),
                  _buildContextField(
                    controller: _communityDescriptionController,
                    label: 'Descrição',
                    hint: 'Ex: Dúvidas sobre Flutter, Firebase e deploy web.',
                    minLines: 4,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade300,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _createCommunity(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'Criar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createCommunity(BuildContext dialogContext) async {
    final name = _communityNameController.text.trim();
    final description = _communityDescriptionController.text.trim();
    final icon = _communityIconController.text.trim().isEmpty
        ? '💬'
        : _communityIconController.text.trim();

    if (name.length < 3 || description.length < 12) {
      _showAISnackBar('Informe nome e descrição da comunidade.');
      return;
    }

    final community = Community(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      members: 1,
      icon: String.fromCharCode(icon.runes.first),
      isCustom: true,
      isFollowed: true,
    );

    await _databaseService.saveCustomCommunity({
      ...community.toJson(),
      'ownerId': _activeUser.id,
      'ownerName': _activeUser.name,
    });

    if (!mounted) return;

    setState(() {
      _communities.insert(0, community);
      _selectedCommunity = community;
    });

    Navigator.pop(dialogContext);
    _showAISnackBar('Comunidade criada.');
  }

  Widget _buildCommunityCard(Community community) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCommunity = community;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: community.isFollowed
                ? primaryCyan.withValues(alpha: 0.45)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(community.icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    community.description,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.group_outlined, size: 14, color: primaryCyan),
                      const SizedBox(width: 4),
                      Text(
                        '${community.members} membros',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_forward, size: 14, color: primaryCyan),
                      const SizedBox(width: 3),
                      Text(
                        'Entrar',
                        style: TextStyle(color: primaryCyan, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: community.isFollowed
                    ? const Color(0xFF0F171A)
                    : primaryCyan,
                foregroundColor: community.isFollowed
                    ? primaryCyan
                    : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
              onPressed: () => _toggleCommunityFollow(community),
              child: Text(
                community.isFollowed ? 'Seguindo' : 'Seguir',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityDetailContent(Community community) {
    final relatedPosts = _postsForCommunity(community);
    final topics = _topicsForCommunity(community);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedCommunity = null;
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Comunidades'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      community.icon,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${community.members} membros • ${relatedPosts.length} posts',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                community.description,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: community.isFollowed
                            ? const Color(0xFF0F171A)
                            : primaryCyan,
                        foregroundColor: community.isFollowed
                            ? primaryCyan
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _toggleCommunityFollow(community),
                      icon: Icon(
                        community.isFollowed
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                      ),
                      label: Text(
                        community.isFollowed ? 'Seguindo' : 'Seguir comunidade',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Criar dúvida',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F171A),
                      foregroundColor: primaryCyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        _showCreateDoubtDialog(community: community),
                    icon: const Icon(Icons.edit_note_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Tópicos em destaque',
          style: TextStyle(color: primaryCyan, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.map((topic) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10191D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                topic,
                style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Discussões recentes',
              style: TextStyle(color: primaryCyan, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${relatedPosts.length}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (relatedPosts.isEmpty)
          _buildEmptyFeedState(community.name)
        else
          ...relatedPosts.map(_buildPostCardWidget),
      ],
    );
  }

  List<Post> _postsForCommunity(Community community) {
    final wantedTags = _tagsForCommunity(community).map((tag) {
      return tag.toLowerCase();
    }).toSet();

    return _allPosts.where((post) {
      return post.communityId == community.id ||
          post.tags.any((tag) => wantedTags.contains(tag.toLowerCase()));
    }).toList();
  }

  List<String> _tagsForCommunity(Community community) {
    switch (community.id) {
      case '1':
        return ['Flutter', 'Dart', 'Firebase', 'Arquitetura'];
      case '2':
        return ['AI', 'Python', 'ML', 'Estudo'];
      case '3':
        return ['JavaScript', 'Backend', 'Web'];
      case '4':
        return ['Backend', 'Firebase', 'Banco'];
      case '5':
        return ['Estudo', 'PFC', 'Projeto'];
      default:
        return ['AI'];
    }
  }

  List<String> _topicsForCommunity(Community community) {
    switch (community.id) {
      case '1':
        return ['Widgets', 'Estado', 'Firebase', 'Deploy web'];
      case '2':
        return ['Prompts', 'Gemini', 'Revisão de código', 'Automação'];
      case '3':
        return ['APIs', 'React', 'JavaScript', 'Front-end'];
      case '4':
        return ['Firestore', 'Modelagem', 'Regras', 'Consultas'];
      case '5':
        return ['PFC', 'Portfólio', 'Apresentação', 'Organização'];
      default:
        return ['Dúvidas', 'Projetos', 'Estudos'];
    }
  }

  // ============= PROFILE CONTENT =============

  Widget _buildProfileContent() {
    if (_activeUser.isGuest) {
      return _buildGuestProfileContent();
    }

    if (_selectedProfileSection != null) {
      return _buildProfileDetailContent(_selectedProfileSection!);
    }

    final userPosts = _currentUserPosts();
    final userComments = _currentUserComments();
    final followedCommunities = _followedCommunities();
    final aiQuestionCount = _chatMessages.where((message) {
      return message.isUser;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileAccountHeader(
            userPosts.length,
            userComments.length,
            followedCommunities.length,
            aiQuestionCount,
          ),
          const SizedBox(height: 16),
          _buildProfileActivityGrid(
            userPosts.length,
            userComments.length,
            followedCommunities.length,
            aiQuestionCount,
          ),
          const SizedBox(height: 18),
          _buildProfileActivitySection(
            title: 'Minhas dúvidas',
            emptyText: 'Você ainda não publicou dúvidas.',
            children: userPosts.take(3).map(_buildProfilePostTile).toList(),
          ),
          const SizedBox(height: 18),
          _buildProfileActivitySection(
            title: 'Meus comentários',
            emptyText: 'Você ainda não comentou em discussões.',
            children: userComments
                .take(3)
                .map(_buildProfileCommentTile)
                .toList(),
          ),
          const SizedBox(height: 18),
          _buildProfileCommunitiesSection(followedCommunities),
          const SizedBox(height: 18),
          _buildProfileDataAccessSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Post> _currentUserPosts() {
    return _allPosts.where((post) {
      return post.id.startsWith('user-') || post.username == _activeUser.name;
    }).toList();
  }

  List<PostComment> _currentUserComments() {
    final comments = _postComments.values.expand((items) => items).where((
      comment,
    ) {
      return comment.authorId == _activeUser.id;
    }).toList();

    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return comments;
  }

  List<Community> _followedCommunities() {
    return _communities.where((community) => community.isFollowed).toList();
  }

  Widget _buildProfileAccountHeader(
    int postCount,
    int commentCount,
    int communityCount,
    int aiQuestionCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProfileAvatar(radius: 28, editable: true),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeUser.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_activeUser.username} • ${_activeUser.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dados pessoais',
                onPressed: () {
                  setState(() {
                    _selectedProfileSection = 'personal';
                    _profileEditing = false;
                  });
                },
                icon: Icon(Icons.badge_outlined, color: primaryCyan),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildProfileMiniStat('$postCount', 'dúvidas')),
              Expanded(
                child: _buildProfileMiniStat('$commentCount', 'comentários'),
              ),
              Expanded(
                child: _buildProfileMiniStat('$communityCount', 'comunidades'),
              ),
              Expanded(child: _buildProfileMiniStat('$aiQuestionCount', 'IA')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar({required double radius, bool editable = false}) {
    final photoBytes = _profilePhotoBytes();

    return GestureDetector(
      onTap: editable ? _pickProfilePhoto : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: primaryCyan.withValues(alpha: 0.18),
            backgroundImage: photoBytes == null
                ? null
                : MemoryImage(photoBytes),
            child: photoBytes == null
                ? Icon(Icons.person, size: radius, color: primaryCyan)
                : null,
          ),
          if (editable)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primaryCyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF162126), width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Uint8List? _profilePhotoBytes() {
    final photoBase64 = _activeUser.photoBase64;
    if (photoBase64 == null || photoBase64.isEmpty) return null;

    try {
      return base64Decode(photoBase64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_activeUser.isGuest) return;

    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _showAISnackBar('Não consegui ler a foto selecionada.');
        return;
      }

      if (bytes.length > 600 * 1024) {
        _showAISnackBar('Foto muito grande. Use uma imagem com até 600 KB.');
        return;
      }

      await _saveProfileChanges(photoBase64: base64Encode(bytes));
    } catch (error) {
      _showAISnackBar('Erro ao selecionar foto: $error');
    }
  }

  Future<void> _saveProfileChanges({String? photoBase64}) async {
    final name = _profileNameController.text.trim();
    final username = _normalizeUsername(_profileUsernameController.text);

    if (name.length < 3) {
      _showAISnackBar('Informe um nome com pelo menos 3 caracteres.');
      return;
    }

    if (username.length < 3) {
      _showAISnackBar('Informe um nome de usuário válido.');
      return;
    }

    final updatedUser = await _databaseService.updateCurrentUserProfile(
      name: name,
      username: username,
      photoBase64: photoBase64 ?? _activeUser.photoBase64,
    );

    if (updatedUser == null) {
      _showAISnackBar('Não consegui salvar o perfil agora.');
      return;
    }

    setState(() {
      _activeUser = updatedUser;
      _profileNameController.text = updatedUser.name;
      _profileUsernameController.text = updatedUser.username;
      _profileEditing = false;
    });

    _showAISnackBar('Perfil atualizado.');
  }

  String _normalizeUsername(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_@.]'),
      '',
    );

    if (cleaned.isEmpty) return '';
    return cleaned.startsWith('@') ? cleaned : '@$cleaned';
  }

  Widget _buildProfileMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: primaryCyan,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildProfileActivityGrid(
    int postCount,
    int commentCount,
    int communityCount,
    int aiQuestionCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildProfileActionCard(
            icon: Icons.edit_note_rounded,
            title: 'Publicar',
            subtitle: '$postCount dúvidas • $commentCount comentários',
            onTap: () => _showCreateDoubtDialog(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildProfileActionCard(
            icon: Icons.psychology_alt_rounded,
            title: 'Histórico IA',
            subtitle:
                '$aiQuestionCount conversas • $communityCount comunidades',
            onTap: _showAIHistorySheet,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF10191D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryCyan, size: 22),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActivitySection({
    required String title,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: primaryCyan,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: children.isEmpty
              ? Text(
                  emptyText,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                )
              : Column(
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1)
                        Divider(color: Colors.white.withValues(alpha: 0.06)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProfilePostTile(Post post) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPost = post;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.question_answer_outlined, color: primaryCyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_visibleCommentCount(post)} comentários • ${post.timeAgo}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCommentTile(PostComment comment) {
    Post? relatedPost;
    for (final post in _allPosts) {
      if (post.id == comment.postId) {
        relatedPost = post;
        break;
      }
    }

    return GestureDetector(
      onTap: relatedPost == null
          ? null
          : () {
              setState(() {
                _selectedPost = relatedPost;
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: primaryCyan,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    relatedPost?.title ?? 'Discussão salva',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (relatedPost != null)
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCommunitiesSection(List<Community> followedCommunities) {
    return _buildProfileActivitySection(
      title: 'Comunidades seguidas',
      emptyText: 'Você ainda não segue comunidades.',
      children: followedCommunities.take(4).map((community) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = 1;
              _selectedCommunity = community;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(community.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${community.members} membros',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfileDataAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conta',
          style: TextStyle(
            color: primaryCyan,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildProfileAccessTile(
                icon: Icons.badge_outlined,
                title: 'Dados pessoais',
                subtitle: 'Nome, e-mail e telefone',
                onTap: () {
                  setState(() {
                    _selectedProfileSection = 'personal';
                    _profileEditing = false;
                  });
                },
              ),
              Divider(color: Colors.white.withValues(alpha: 0.06)),
              _buildProfileAccessTile(
                icon: Icons.home_work_outlined,
                title: 'Endereço',
                subtitle: 'CEP, rua, cidade e estado',
                onTap: () {
                  setState(() {
                    _selectedProfileSection = 'address';
                    _profileEditing = false;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAccessTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailContent(String section) {
    final isPersonal = section == 'personal';
    final title = isPersonal ? 'Dados pessoais' : 'Endereço';
    final subtitle = isPersonal
        ? 'Atualize as informações básicas da sua conta.'
        : 'Mantenha seu endereço organizado para futuras funções.';
    final icon = isPersonal ? Icons.badge_outlined : Icons.home_work_outlined;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Voltar ao perfil',
                onPressed: () {
                  setState(() {
                    _selectedProfileSection = null;
                    _profileEditing = false;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded, color: primaryCyan),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (_profileEditing) {
                    await _saveProfileChanges();
                    return;
                  }

                  setState(() {
                    _profileEditing = true;
                  });
                },
                icon: Icon(
                  _profileEditing
                      ? Icons.check_circle_rounded
                      : Icons.edit_rounded,
                  size: 17,
                ),
                label: Text(_profileEditing ? 'Concluir' : 'Editar'),
                style: TextButton.styleFrom(foregroundColor: primaryCyan),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryCyan.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primaryCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primaryCyan),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isPersonal)
            _buildProfileSection('Informações', [
              Row(
                children: [
                  _buildProfileAvatar(radius: 34, editable: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto de perfil',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Clique na foto para trocar.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _buildProfileTextField(
                'Nome Completo',
                _profileNameController,
                Icons.person,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Nome de usuário',
                _profileUsernameController,
                Icons.alternate_email_rounded,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Email',
                _profileEmailController,
                Icons.email,
                enabled: false,
              ),
              _buildProfileTextField(
                'Telefone',
                _profilePhoneController,
                Icons.phone,
                enabled: _profileEditing,
              ),
            ])
          else
            _buildProfileSection('Localização', [
              _buildCEPField(),
              _buildProfileTextField(
                'Rua',
                _profileRuaController,
                Icons.streetview,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Número',
                _profileNumeroController,
                Icons.home,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Complemento',
                _profileComplementoController,
                Icons.info_outline,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Bairro',
                _profileBairroController,
                Icons.location_city,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Cidade',
                _profileCidadeController,
                Icons.business,
                enabled: _profileEditing,
              ),
              _buildProfileTextField(
                'Estado',
                _profileEstadoController,
                Icons.map,
                enabled: _profileEditing,
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildGuestProfileContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: primaryCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: primaryCyan,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Crie sua conta no DevStack AI',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Você está navegando como visitante. Com uma conta, suas dúvidas e interações ficam salvas para continuar depois.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _buildGuestBenefit(
                Icons.edit_note_rounded,
                'Publique dúvidas no feed',
              ),
              _buildGuestBenefit(
                Icons.bookmark_border_rounded,
                'Salve posts importantes',
              ),
              _buildGuestBenefit(
                Icons.cloud_done_outlined,
                'Sincronize seus dados no Firebase',
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Entrar ou criar conta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10191D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primaryCyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Você ainda pode usar o chat com IA e visualizar comunidades sem conta.',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        children: [
          Icon(icon, color: primaryCyan, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade200, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCEPField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '📍 CEP *',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _profileCepController,
                enabled: _profileEditing,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '00000000',
                  hintStyle: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F171A),
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: Colors.orange,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                ),
                onChanged: (value) {
                  setState(() {
                    _cepError = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            if (_profileEditing)
              GestureDetector(
                onTap: _profileCepController.text.length == 8
                    ? _consultarCEP
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _profileCepController.text.length == 8
                        ? primaryCyan
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _cepLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _profileCepController.text.length == 8
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.search,
                          color: _profileCepController.text.length == 8
                              ? Colors.black
                              : Colors.grey,
                        ),
                ),
              ),
          ],
        ),
        if (_cepError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _cepError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '* Campo obrigatório - Consulte seu CEP para autopreenchimento de endereço',
          style: TextStyle(
            color: Colors.orange.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============= AI CONVERSATION CONTENT =============

  Widget _buildAIConversationContent() {
    return Column(
      children: [
        _buildAIChatToolbar(),
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildAIEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = _chatMessages[index];
                    return Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? primaryCyan
                              : const Color(0xFF10191D),
                          borderRadius: BorderRadius.circular(14),
                          border: !message.isUser
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChatMessageContent(message),
                            if (!message.isUser) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: 'Copiar resposta',
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: message.text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Resposta copiada.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    color: Colors.grey.shade500,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isLoadingAI) _buildAILoadingStatus(),
        _buildAIContextAttachmentStrip(),
        _buildAIMessageInput(),
      ],
    );
  }

  Widget _buildChatMessageContent(ChatMessage message) {
    if (message.isUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.trim().isNotEmpty)
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          if (message.attachments.isNotEmpty) ...[
            if (message.text.trim().isNotEmpty) const SizedBox(height: 10),
            _buildMessageAttachmentPreview(message.attachments),
          ],
        ],
      );
    }

    return _buildFormattedAIResponse(message.text);
  }

  Widget _buildMessageAttachmentPreview(List<AIContextAttachment> attachments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        return Container(
          width: 92,
          height: 92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: attachment.isImage && attachment.bytes != null
                    ? Image.memory(attachment.bytes!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.black.withValues(alpha: 0.12),
                        child: Icon(
                          attachment.icon,
                          color: Colors.black.withValues(alpha: 0.7),
                          size: 32,
                        ),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 10, 7, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                  child: Text(
                    attachment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAILoadingStatus() {
    final hasAttachments = _aiRequestHasAttachments;
    final steps = hasAttachments
        ? ['Lendo pergunta', 'Analisando anexos', 'Preparando resposta']
        : ['Lendo pergunta', 'Consultando IA', 'Preparando resposta'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10191D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: steps.map((step) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    step,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedAIResponse(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final codeBuffer = <String>[];
    var isInsideCodeBlock = false;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        if (isInsideCodeBlock) {
          widgets.add(_buildAITextCodeBlock(codeBuffer.join('\n')));
          codeBuffer.clear();
        }
        isInsideCodeBlock = !isInsideCodeBlock;
        continue;
      }

      if (isInsideCodeBlock) {
        codeBuffer.add(line);
        continue;
      }

      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('###')) {
        widgets.add(
          _buildAIHeading(
            trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
            small: true,
          ),
        );
      } else if (trimmed.startsWith('##') || trimmed.startsWith('#')) {
        widgets.add(
          _buildAIHeading(trimmed.replaceFirst(RegExp(r'^#+\s*'), '')),
        );
      } else if (_isBulletLine(trimmed)) {
        widgets.add(
          _buildAIBullet(trimmed.replaceFirst(RegExp(r'^[-*•]\s*'), '')),
        );
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(trimmed);
        widgets.add(
          _buildAINumberedItem(
            match?.group(1) ?? '',
            match?.group(2) ?? trimmed,
          ),
        );
      } else {
        widgets.add(_buildAIParagraph(trimmed));
      }
    }

    if (codeBuffer.isNotEmpty) {
      widgets.add(_buildAITextCodeBlock(codeBuffer.join('\n')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  bool _isBulletLine(String text) {
    return text.startsWith('- ') ||
        text.startsWith('* ') ||
        text.startsWith('• ');
  }

  Widget _buildAIHeading(String text, {bool small = false}) {
    return Padding(
      padding: EdgeInsets.only(top: small ? 6 : 8, bottom: 6),
      child: Text(
        _cleanMarkdownInline(text),
        style: TextStyle(
          color: primaryCyan,
          fontSize: small ? 14 : 15,
          height: 1.25,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAIParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText(
        _cleanMarkdownInline(text),
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
      ),
    );
  }

  Widget _buildAIBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 9),
            decoration: BoxDecoration(
              color: primaryCyan,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: _buildAIParagraph(text)),
        ],
      ),
    );
  }

  Widget _buildAINumberedItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              color: primaryCyan,
              fontWeight: FontWeight.bold,
              height: 1.45,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildAIParagraph(text)),
        ],
      ),
    );
  }

  Widget _buildAITextCodeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091013),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryCyan.withValues(alpha: 0.16)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          code.trimRight(),
          style: GoogleFonts.firaCode(
            color: Colors.greenAccent,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  String _cleanMarkdownInline(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(RegExp(r'__(.*?)__'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`([^`]*)`'), (match) => match.group(1) ?? '')
        .trim();
  }

  Widget _buildAIChatToolbar() {
    final savedQuestionCount = _chatMessages.where((message) {
      return message.isUser;
    }).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1215),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryCyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, color: primaryCyan, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistente DevStack',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  savedQuestionCount == 0
                      ? 'Histórico salvo por usuário'
                      : '$savedQuestionCount pergunta(s) neste histórico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Histórico da IA',
            onPressed: _showAIHistorySheet,
            icon: Icon(
              Icons.history_rounded,
              color: _chatMessages.isEmpty ? Colors.grey : primaryCyan,
              size: 21,
            ),
          ),
          if (_chatMessages.isNotEmpty)
            IconButton(
              tooltip: 'Limpar conversa',
              onPressed: _clearAIChatHistory,
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  void _showAIHistorySheet() {
    final recentQuestions = _chatMessages
        .where((message) => message.isUser)
        .toList()
        .reversed
        .take(8)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1215),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: primaryCyan),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Histórico da IA',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _activeUser.isGuest
                      ? 'No modo visitante, o histórico fica salvo somente neste navegador.'
                      : 'Este histórico pertence à conta ${_activeUser.email}.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (recentQuestions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Nenhuma conversa salva ainda.',
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                  )
                else
                  ...recentQuestions.map((message) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _aiMessageController.text = message.text;
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: primaryCyan,
                              size: 17,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                message.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIEmptyState() {
    final suggestions = [
      {
        'title': 'Explicar erro',
        'subtitle': 'Cole a mensagem e diga onde aconteceu.',
        'icon': Icons.bug_report_outlined,
        'template':
            'Explique este erro em português, como se eu estivesse aprendendo.\n\nErro:\n\nOnde aconteceu:\n\nO que eu já tentei:',
      },
      {
        'title': 'Revisar código',
        'subtitle': 'Peça melhorias, bugs e organização.',
        'icon': Icons.code_rounded,
        'template':
            'Revise este código e aponte possíveis erros, melhorias e uma versão corrigida se fizer sentido.\n\nCódigo:\n\nObjetivo do código:',
      },
      {
        'title': 'Planejar solução',
        'subtitle': 'Transforme uma ideia em próximos passos.',
        'icon': Icons.route_outlined,
        'template':
            'Me ajude a planejar esta funcionalidade no meu app Flutter.\n\nFuncionalidade:\n\nO que ela precisa fazer:\n\nDúvidas que tenho:',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF10191D),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 30,
                    color: primaryCyan,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Assistente pronto para ajudar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Escolha um modelo abaixo, complete com seus detalhes e envie. Assim a IA responde com contexto de verdade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Comece com um modelo',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          ...suggestions.map((suggestion) {
            return _buildAIPromptSuggestion(
              title: suggestion['title']! as String,
              subtitle: suggestion['subtitle']! as String,
              icon: suggestion['icon']! as IconData,
              template: suggestion['template']! as String,
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryCyan.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryCyan.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file_rounded, color: primaryCyan, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Você também pode anexar contexto, código, enunciado ou imagem antes de enviar.',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showAIContextSheet,
                  child: Text(
                    'Anexar',
                    style: TextStyle(
                      color: primaryCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIPromptSuggestion({
    required String title,
    required String subtitle,
    required IconData icon,
    required String template,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isLoadingAI
            ? null
            : () {
                _applyAIPromptTemplate(template);
              },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF0F171A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryCyan.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: primaryCyan, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_rounded,
                color: Colors.grey.withValues(alpha: 0.55),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyAIPromptTemplate(String template) {
    setState(() {
      _aiMessageController.text = template;
      _aiMessageController.selection = TextSelection.collapsed(
        offset: template.length,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _aiMessageFocusNode.requestFocus();
    });
  }

  void _showAIContextSheet() {
    const contextTypes = [
      {'label': 'Erro', 'icon': Icons.bug_report_outlined},
      {'label': 'Código', 'icon': Icons.code_rounded},
      {'label': 'Enunciado', 'icon': Icons.article_outlined},
      {'label': 'Objetivo', 'icon': Icons.flag_outlined},
    ];

    var selectedType = contextTypes.first['label']! as String;
    _aiContextTitleController.clear();
    _aiContextContentController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF101A1F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryCyan.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.attach_file_rounded,
                                color: primaryCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Anexar contexto',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Organize o material antes de enviar para a IA.',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAttachmentOption(
                                icon: Icons.image_outlined,
                                title: 'Foto ou print',
                                subtitle: 'PNG, JPG ou WEBP',
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickAIImageAttachment();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildAttachmentOption(
                                icon: Icons.description_outlined,
                                title: 'Arquivo',
                                subtitle: 'Texto ou código',
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickAITextFileAttachment();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.cloud_download_outlined,
                                color: primaryCyan,
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Você também pode copiar uma imagem e usar Ctrl + V nesta aba. Se o botão Abrir ficar desabilitado, baixe o arquivo do OneDrive antes.',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'ou cole manualmente',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: contextTypes.map((type) {
                            final label = type['label']! as String;
                            final icon = type['icon']! as IconData;

                            return _buildContextTypeButton(
                              label: label,
                              icon: icon,
                              isSelected: selectedType == label,
                              onTap: () {
                                setModalState(() {
                                  selectedType = label;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildContextField(
                          controller: _aiContextTitleController,
                          label: 'Título curto',
                          hint: 'Ex: Erro ao autenticar usuário',
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        _buildContextField(
                          controller: _aiContextContentController,
                          label: 'Conteúdo',
                          hint:
                              'Cole o erro, código, enunciado ou explique o objetivo...',
                          minLines: 5,
                          maxLines: 10,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade300,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryCyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  final title = _aiContextTitleController.text
                                      .trim();
                                  final content = _aiContextContentController
                                      .text
                                      .trim();

                                  if (title.isEmpty || content.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Preencha título e conteúdo do anexo.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() {
                                    _aiContextAttachments.add(
                                      AIContextAttachment(
                                        type: selectedType,
                                        title: title,
                                        content: content,
                                        icon: _iconForContextType(selectedType),
                                      ),
                                    );
                                  });

                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text(
                                  'Adicionar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContextTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryCyan.withValues(alpha: 0.16)
              : const Color(0xFF0B1215),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? primaryCyan
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryCyan : Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryCyan : Colors.grey.shade300,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1215),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryCyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryCyan, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1215),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.55)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForContextType(String type) {
    switch (type) {
      case 'Erro':
        return Icons.bug_report_outlined;
      case 'Código':
        return Icons.code_rounded;
      case 'Enunciado':
        return Icons.article_outlined;
      case 'Objetivo':
        return Icons.flag_outlined;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Future<void> _pickAIImageAttachment() async {
    await _pickAIFileAttachment(type: FileType.any, imageOnly: true);
  }

  void _handlePastedImageAttachment(PastedImageData image) {
    if (!mounted || _selectedIndex != 3) return;

    if (image.bytes.length > 4 * 1024 * 1024) {
      _showAISnackBar(
        'Imagem muito grande. Use um print menor ou compacte para até 4 MB.',
      );
      return;
    }

    setState(() {
      _aiContextAttachments.add(
        AIContextAttachment(
          type: 'Imagem',
          title: image.name,
          content:
              'Imagem colada no chat para análise visual: ${image.name}. Observe prints de erro, tela do app, código visível ou enunciado na imagem.',
          icon: Icons.image_outlined,
          bytes: image.bytes,
          mimeType: image.mimeType,
          fileName: image.name,
        ),
      );
    });

    _showAISnackBar('Imagem colada no chat.');
  }

  Future<void> _pickAITextFileAttachment() async {
    await _pickAIFileAttachment(
      type: FileType.custom,
      allowedExtensions: _readableTextExtensions.toList(),
    );
  }

  Future<void> _pickAIFileAttachment({
    required FileType type,
    List<String>? allowedExtensions,
    bool imageOnly = false,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
        type: type,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) {
        _showAISnackBar('Não consegui ler o arquivo selecionado.');
        return;
      }

      final mimeType = _mimeTypeForFileName(file.name);
      final isImage = mimeType.startsWith('image/');
      final isTextFile = _isReadableTextFile(file.name);

      if (imageOnly && !isImage) {
        _showAISnackBar('Escolha uma imagem PNG, JPG, JPEG ou WEBP.');
        return;
      }

      if (!isImage && !isTextFile) {
        _showAISnackBar(
          'Formato não suportado ainda. Use imagem ou arquivo de texto/código.',
        );
        return;
      }

      if (isImage && bytes.length > 4 * 1024 * 1024) {
        _showAISnackBar(
          'Imagem muito grande. Use um print menor ou compacte para até 4 MB.',
        );
        return;
      }

      var content = 'Arquivo anexado: ${file.name}';
      if (isImage) {
        content =
            'Imagem anexada para análise visual: ${file.name}. Observe prints de erro, tela do app, código visível ou enunciado na imagem.';
      } else {
        content = utf8.decode(bytes, allowMalformed: true).trim();
        if (content.length > 12000) {
          content =
              '${content.substring(0, 12000)}\n\n[Conteúdo truncado para envio à IA.]';
        }
      }

      setState(() {
        _aiContextAttachments.add(
          AIContextAttachment(
            type: isImage ? 'Imagem' : 'Arquivo',
            title: file.name,
            content: content,
            icon: isImage ? Icons.image_outlined : Icons.description_outlined,
            bytes: isImage ? bytes : null,
            mimeType: isImage ? mimeType : null,
            fileName: file.name,
          ),
        );
      });

      _showAISnackBar('Anexo adicionado: ${file.name}');
    } catch (error) {
      _showAISnackBar('Erro ao selecionar arquivo: $error');
    }
  }

  Set<String> get _readableTextExtensions {
    return {
      'txt',
      'md',
      'dart',
      'js',
      'ts',
      'html',
      'css',
      'json',
      'yaml',
      'yml',
      'log',
      'py',
      'java',
      'kt',
      'swift',
      'csv',
      'xml',
      'sql',
    };
  }

  bool _isReadableTextFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return _readableTextExtensions.contains(extension);
  }

  String _mimeTypeForFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      case 'jfif':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'text/plain';
    }
  }

  void _showAISnackBar(String message) {
    final bottomOffset = 92.0 + (_aiContextAttachments.isEmpty ? 0.0 : 112.0);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: primaryCyan, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomOffset),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10191D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: primaryCyan.withValues(alpha: 0.18)),
          ),
        ),
      );
  }

  Widget _buildAIContextAttachmentStrip() {
    if (_aiContextAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      color: const Color(0xFF0B1215),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _aiContextAttachments.map((attachment) {
            return Container(
              width: 96,
              height: 96,
              margin: const EdgeInsets.only(right: 10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF0F171A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: attachment.isImage && attachment.bytes != null
                        ? Image.memory(attachment.bytes!, fit: BoxFit.cover)
                        : Container(
                            color: primaryCyan.withValues(alpha: 0.08),
                            child: Icon(
                              attachment.icon,
                              color: primaryCyan,
                              size: 32,
                            ),
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(7, 14, 7, 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Text(
                        attachment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        setState(() {
                          _aiContextAttachments.remove(attachment);
                        });
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAIMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1215),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF10191D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: IconButton(
                tooltip: 'Anexar contexto',
                onPressed: _isLoadingAI ? null : _showAIContextSheet,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.add_rounded,
                  color: _isLoadingAI
                      ? Colors.grey.withValues(alpha: 0.5)
                      : primaryCyan,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10191D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: TextField(
                  controller: _aiMessageController,
                  focusNode: _aiMessageFocusNode,
                  enabled: !_isLoadingAI,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escreva sua dúvida ou complete o modelo...',
                    hintStyle: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.65),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isLoadingAI ? null : _sendAIMessageFromInput,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isLoadingAI
                      ? Colors.grey.withValues(alpha: 0.35)
                      : primaryCyan,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _isLoadingAI
                      ? []
                      : [
                          BoxShadow(
                            color: primaryCyan.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final unreadCount = _unreadNotificationCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isShowingSearch
                      ? primaryCyan.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.search,
                    color: _isShowingSearch ? primaryCyan : Colors.grey,
                  ),
                  onPressed: () {
                    _changeScreen();
                    setState(() {
                      _isShowingSearch = !_isShowingSearch;
                      _isShowingNotifications = false;
                    });
                  },
                ),
              ),
              Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _isShowingNotifications
                          ? primaryCyan.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: _isShowingNotifications
                            ? primaryCyan
                            : Colors.grey,
                      ),
                      onPressed: () {
                        _changeScreen();
                        setState(() {
                          _isShowingNotifications = !_isShowingNotifications;
                          _isShowingSearch = false;
                        });
                      },
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF0B1215),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, color: primaryCyan),
              const SizedBox(width: 5),
              Text(
                'DevStack',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                ' AI',
                style: TextStyle(
                  color: primaryCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showAISettingsModal,
            child: Icon(Icons.settings, color: primaryCyan, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsRow() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedTagIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTagIndex = index;
                _isShowingSearch = false;
                _isShowingNotifications = false;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryCyan.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryCyan
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index == 0) ...[
                    Icon(
                      Icons.dynamic_feed_outlined,
                      color: isSelected ? primaryCyan : Colors.grey,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    tags[index],
                    style: TextStyle(
                      color: isSelected ? primaryCyan : Colors.grey,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostDetailContent(Post post) {
    final comments = _commentsForPost(post);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1215),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                onPressed: () {
                  setState(() {
                    _selectedPost = null;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded, color: primaryCyan),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  post.isQuestion ? 'Detalhes da dúvida' : 'Detalhes do post',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: post.isQuestion
                    ? 'Pedir ajuda da IA'
                    : 'Explicar com IA',
                onPressed: () => _askAIAboutPost(post),
                icon: Icon(Icons.psychology_alt_rounded, color: primaryCyan),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10191D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: primaryCyan.withValues(alpha: 0.18),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: primaryCyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${post.userHandle} • ${post.timeAgo}',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (post.isQuestion)
                          _miniTag('Dúvida', color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      post.title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post.description,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    if (post.code.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1215),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryCyan.withValues(alpha: 0.12),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            post.code,
                            style: GoogleFonts.firaCode(
                              color: Colors.greenAccent.shade100,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (post.communityName != null)
                          _miniTag(post.communityName!, color: Colors.amber),
                        ...post.tags.map((tag) => _miniTag(tag)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildDetailStat(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          '${post.likes + (post.isLiked ? 1 : 0)}',
                          post.isLiked ? Colors.redAccent : primaryCyan,
                          () => _togglePostLike(post),
                        ),
                        const SizedBox(width: 14),
                        _buildDetailStat(
                          Icons.chat_bubble_outline_rounded,
                          '${_visibleCommentCount(post)}',
                          Colors.grey,
                          null,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _askAIAboutPost(post),
                          icon: const Icon(Icons.psychology, size: 17),
                          label: const Text('Pedir ajuda'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Comentários recentes',
                    style: TextStyle(
                      color: primaryCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${comments.length}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (comments.isEmpty)
                _buildEmptyCommentsState()
              else
                ...comments.map(_buildCommentCard),
            ],
          ),
        ),
        _buildCommentComposer(post),
      ],
    );
  }

  Widget _buildDetailStat(
    IconData icon,
    String value,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyCommentsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10191D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        'Ainda não há comentários salvos nessa discussão.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      ),
    );
  }

  Widget _buildCommentCard(PostComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF10191D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: primaryCyan.withValues(alpha: 0.16),
            child: Icon(Icons.person, size: 14, color: primaryCyan),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer(Post post) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1215),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 3,
                enabled: !_activeUser.isGuest,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: _activeUser.isGuest
                      ? 'Entre para comentar'
                      : 'Escreva uma resposta...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: const Color(0xFF10191D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filled(
                tooltip: 'Enviar comentário',
                style: IconButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () => _publishComment(post),
                icon: const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCardWidget(Post post) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPost = post;
          _isShowingSearch = false;
          _isShowingNotifications = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
        decoration: BoxDecoration(
          color: const Color(0xFF10191D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: primaryCyan.withValues(alpha: 0.18),
                  child: Icon(Icons.person, size: 10, color: primaryCyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (post.isQuestion) ...[
                        const SizedBox(width: 7),
                        _miniTag('Dúvida', color: Colors.orange),
                      ],
                      const SizedBox(width: 7),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _togglePostFavorite(post),
                  child: Icon(
                    post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: post.isFavorited
                        ? primaryCyan
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            if (post.code.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1215),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    post.code,
                    maxLines: 4,
                    overflow: TextOverflow.fade,
                    style: GoogleFonts.firaCode(
                      color: Colors.greenAccent.shade100,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _togglePostLike(post),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: post.isLiked ? Colors.red : primaryCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes + (post.isLiked ? 1 : 0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_visibleCommentCount(post)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: post.isQuestion
                      ? 'Pedir ajuda da IA'
                      : 'Explicar com IA',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _askAIAboutPost(post),
                  icon: Icon(Icons.psychology, color: primaryCyan, size: 18),
                ),
                if (post.code.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Copiar código',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: post.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.copy_rounded,
                      color: Colors.grey.shade500,
                      size: 17,
                    ),
                  ),
              ],
            ),
            if (post.communityName != null || post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (post.communityName != null)
                    _miniTag(post.communityName!, color: Colors.amber),
                  ...post.tags.take(3).map((tag) => _miniTag(tag)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String label, {Color? color}) {
    final tagColor = color ?? primaryCyan;

    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: tagColor, fontSize: 9)),
    );
  }

  Widget _buildFloatingAskButton() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: GestureDetector(
        onTap: _showAskAIDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primaryCyan,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: primaryCyan.withValues(alpha: 0.32),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, color: Colors.black, size: 18),
              SizedBox(width: 6),
              Text(
                'IA',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAISettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: primaryCyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Configurações da IA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F171A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryCyan.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: primaryCyan, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assistente Gemini ativo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Modelo fixo do projeto para evitar configuração duplicada.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade200,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAIHistorySheet();
                    },
                    icon: const Icon(Icons.history_rounded, size: 17),
                    label: const Text('Histórico'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAIContextSheet();
                    },
                    icon: const Icon(Icons.attach_file_rounded, size: 17),
                    label: const Text('Contexto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAskAIDialog() {
    final TextEditingController questionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Row(
          children: [
            Icon(Icons.psychology, color: primaryCyan),
            const SizedBox(width: 8),
            const Text(
              'Perguntar à IA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Faça uma pergunta sobre código ou desenvolvimento:',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                maxLines: 5,
                minLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Como otimizar um useEffect em React?',
                  hintStyle: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F171A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final question = questionController.text.trim();
              if (question.isNotEmpty) {
                Navigator.pop(context);
                _sendQuestionToAI(question);
                questionController.clear();
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _sendAIMessageFromInput() {
    final question = _aiMessageController.text.trim();
    if ((question.isEmpty && _aiContextAttachments.isEmpty) || _isLoadingAI) {
      return;
    }

    final prompt = _composeAIQuestion(question);
    final displayText = _composeAIMessagePreview(question);
    final displayAttachments = List<AIContextAttachment>.from(
      _aiContextAttachments,
    );
    final attachmentParts = _buildGeminiAttachmentParts();
    _aiMessageController.clear();

    setState(() {
      _aiContextAttachments.clear();
    });

    _sendQuestionToAI(
      prompt,
      displayText: displayText,
      displayAttachments: displayAttachments,
      attachmentParts: attachmentParts,
    );
  }

  void _askAIAboutPost(Post post) {
    final buffer = StringBuffer()
      ..writeln(
        'Me ajude com esta ${post.isQuestion ? 'dúvida' : 'publicação'} do DevStack AI.',
      )
      ..writeln()
      ..writeln('Título: ${post.title}')
      ..writeln('Descrição: ${post.description}')
      ..writeln('Tags: ${post.tags.join(', ')}');

    if (post.code.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Código/erro:')
        ..writeln(post.code);
    }

    buffer
      ..writeln()
      ..writeln(
        'Explique o problema, sugira uma solução e, se possível, mostre um exemplo.',
      );

    _sendQuestionToAI(buffer.toString());
  }

  String _composeAIQuestion(String question) {
    if (_aiContextAttachments.isEmpty) {
      return question;
    }

    final buffer = StringBuffer();

    if (question.isNotEmpty) {
      buffer
        ..writeln('Pergunta principal:')
        ..writeln(question)
        ..writeln();
    } else {
      buffer
        ..writeln('Analise os contextos anexados e me ajude a avançar.')
        ..writeln();
    }

    buffer.writeln('Contextos anexados:');
    for (var i = 0; i < _aiContextAttachments.length; i++) {
      final attachment = _aiContextAttachments[i];
      buffer
        ..writeln()
        ..writeln('${i + 1}. ${attachment.type}: ${attachment.title}')
        ..writeln('```')
        ..writeln(attachment.content)
        ..writeln('```');
    }

    buffer
      ..writeln()
      ..writeln(
        'Responda conectando a pergunta aos contextos anexados. Se houver erro ou código, explique a causa provável e proponha correção passo a passo.',
      );

    return buffer.toString();
  }

  String _composeAIMessagePreview(String question) {
    if (_aiContextAttachments.isEmpty) return question;
    if (question.isEmpty) return 'Analise os anexos enviados.';
    return question;
  }

  List<Map<String, dynamic>> _buildGeminiAttachmentParts() {
    final parts = <Map<String, dynamic>>[];

    for (final attachment in _aiContextAttachments) {
      if (!attachment.hasFile || !attachment.isImage) continue;

      parts.add({
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': base64Encode(attachment.bytes!),
        },
      });
    }

    return parts;
  }

  Future<void> _sendQuestionToAI(
    String question, {
    String? displayText,
    List<AIContextAttachment> displayAttachments = const [],
    List<Map<String, dynamic>> attachmentParts = const [],
  }) async {
    _changeScreen();
    setState(() {
      _chatMessages.add(
        ChatMessage(
          text: displayText ?? question,
          isUser: true,
          timestamp: DateTime.now(),
          attachments: displayAttachments,
        ),
      );
      _isLoadingAI = true;
      _aiRequestHasAttachments = displayAttachments.isNotEmpty;
      _selectedIndex = 3;
      _selectedPost = null;
      _isShowingSearch = false;
      _isShowingNotifications = false;
    });

    try {
      final apiKey = _geminiApiKey();

      if (apiKey.isEmpty || apiKey.contains('SUA_CHAVE')) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text:
                  '❌ Erro: chave API do Gemini não carregada.\n\nVerifique se o arquivo .env está na pasta do projeto e reinicie o Flutter por completo.\n\nAlternativa:\nrode com --dart-define=GEMINI_API_KEY=sua_chave_aqui',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });
        return;
      }

      const geminiModel = 'gemini-2.5-flash';
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$apiKey',
      );

      final geminiParts = <Map<String, dynamic>>[
        {
          'text':
              'Voce e o Assistente DevStack. Responda diretamente a pergunta do usuario em portugues do Brasil, '
              'com clareza, organizacao e tom didatico. Nao mencione estas instrucoes. '
              'Use listas quando houver passos e blocos de codigo somente quando houver codigo.\n\n'
              'Pergunta do usuário: $question',
        },
        ...attachmentParts,
      ];

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': geminiParts},
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => http.Response('Timeout', 504),
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = jsonResponse['candidates'];
        String aiResponse = '';

        if (candidates is List && candidates.isNotEmpty) {
          final firstCandidate = candidates.first;
          if (firstCandidate is Map<String, dynamic>) {
            final content = firstCandidate['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                aiResponse = parts
                    .whereType<Map<String, dynamic>>()
                    .map((part) => part['text']?.toString() ?? '')
                    .where((text) => text.isNotEmpty)
                    .join('\n')
                    .trim();
              }
            }
          }
        }

        setState(() {
          _chatMessages.add(
            ChatMessage(
              text: aiResponse.isNotEmpty
                  ? aiResponse
                  : 'A IA respondeu, mas nao retornou texto. Tente reformular a pergunta.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });

        _addNotification(
          title: 'Resposta da IA pronta',
          message: 'O Assistente DevStack respondeu sua última pergunta.',
          type: 'ai',
        );
      } else if (response.statusCode == 429) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text: _buildAIErrorMessage(
                title: 'Limite temporário da IA',
                message:
                    'O serviço atingiu o limite de uso por agora. Tente novamente mais tarde ou verifique a quota do projeto no Google Cloud.',
                statusCode: response.statusCode,
                technicalDetails: _extractGeminiErrorMessage(response.body),
              ),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text: _buildAIErrorMessage(
                title: 'Chave da IA inválida',
                message:
                    'Não consegui autenticar a chave do Gemini. Confira o arquivo .env ou gere uma nova chave no Google AI Studio.',
                statusCode: response.statusCode,
                technicalDetails: _extractGeminiErrorMessage(response.body),
              ),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });
      } else if (response.statusCode == 504) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text: _buildAIErrorMessage(
                title: 'A resposta demorou demais',
                message:
                    'A IA não respondeu dentro do tempo esperado. Tente enviar novamente em alguns segundos.',
                statusCode: response.statusCode,
              ),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });
      } else {
        final errorPreview = _extractGeminiErrorMessage(response.body);
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text: _buildAIErrorMessage(
                title: _friendlyAIErrorTitle(response.statusCode),
                message: _friendlyAIErrorMessage(response.statusCode),
                statusCode: response.statusCode,
                technicalDetails: errorPreview,
              ),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingAI = false;
          _aiRequestHasAttachments = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add(
          ChatMessage(
            text: _buildAIErrorMessage(
              title: 'Falha de conexão',
              message:
                  'Não consegui conversar com a IA agora. Verifique sua internet e tente novamente em alguns segundos.',
              technicalDetails: e.toString(),
            ),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoadingAI = false;
        _aiRequestHasAttachments = false;
      });
    } finally {
      await _saveAIChatHistory();
    }
  }

  String _geminiApiKey() {
    final dotenvKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    if (dotenvKey.isNotEmpty) return dotenvKey;

    return const String.fromEnvironment('GEMINI_API_KEY').trim();
  }

  String _friendlyAIErrorTitle(int statusCode) {
    if (statusCode == 503) return 'A IA está ocupada agora';
    if (statusCode >= 500) return 'Instabilidade temporária da IA';
    if (statusCode == 400) return 'Não consegui processar essa solicitação';
    if (statusCode == 403) return 'Acesso bloqueado pela API';
    return 'Não consegui responder agora';
  }

  String _friendlyAIErrorMessage(int statusCode) {
    if (statusCode == 503) {
      return 'O Gemini está com alta demanda no momento. Tente novamente em alguns segundos.';
    }
    if (statusCode >= 500) {
      return 'O serviço da IA parece estar instável. Aguarde um pouco e tente novamente.';
    }
    if (statusCode == 400) {
      return 'A pergunta ou algum anexo pode estar grande ou em formato incompatível. Tente reduzir o conteúdo e enviar novamente.';
    }
    if (statusCode == 403) {
      return 'A chave atual não tem permissão para acessar esse recurso. Verifique a configuração do projeto no Google Cloud.';
    }
    return 'Tente novamente. Se continuar acontecendo, revise a chave da API e a conexão com a internet.';
  }

  String _buildAIErrorMessage({
    required String title,
    required String message,
    int? statusCode,
    String? technicalDetails,
  }) {
    final buffer = StringBuffer()
      ..writeln('## $title')
      ..writeln()
      ..writeln(message);

    if (statusCode != null) {
      buffer
        ..writeln()
        ..writeln('Status: $statusCode');
    }

    final details = technicalDetails?.trim();
    if (details != null && details.isNotEmpty && details != 'Timeout') {
      buffer
        ..writeln()
        ..writeln('Detalhe técnico: $details');
    }

    return buffer.toString().trim();
  }

  String _extractGeminiErrorMessage(String responseBody) {
    String message = responseBody;

    try {
      final errorJson = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = errorJson['error'];
      if (error is Map<String, dynamic> && error['message'] != null) {
        message = error['message'].toString();
      }
    } catch (_) {
      // Mantem o corpo original quando a resposta nao for JSON.
    }

    if (message.length > 500) {
      return message.substring(0, 500);
    }
    return message;
  }

  Future<void> _consultarCEP() async {
    final cep = _profileCepController.text.replaceAll(RegExp(r'\D'), '');

    if (cep.isEmpty || cep.length != 8) {
      setState(() {
        _cepError = 'CEP inválido. Use apenas 8 dígitos.';
      });
      return;
    }

    setState(() {
      _cepLoading = true;
      _cepError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['erro'] == true) {
          setState(() {
            _cepError = '❌ CEP não encontrado';
            _cepLoading = false;
          });
        } else {
          setState(() {
            _profileRuaController.text = data['logradouro'] ?? '';
            _profileBairroController.text = data['bairro'] ?? '';
            _profileCidadeController.text = data['localidade'] ?? '';
            _profileEstadoController.text = data['uf'] ?? '';
            _cepLoading = false;
            _cepError = null;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ CEP consultado com sucesso!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          });
        }
      } else {
        setState(() {
          _cepError = '❌ Erro ao consultar CEP';
          _cepLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _cepError = '❌ Erro na conexão: ${e.toString()}';
        _cepLoading = false;
      });
    }
  }

  Widget _buildProfileSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: primaryCyan,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F171A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
              prefixIcon: Icon(
                icon,
                color: enabled
                    ? primaryCyan
                    : Colors.grey.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final navItems = [
      {'icon': Icons.home_filled, 'label': 'Início'},
      {'icon': Icons.people_outline, 'label': 'Comunidades'},
      {'icon': Icons.person_outline, 'label': 'Perfil'},
      {'icon': Icons.psychology, 'label': 'IA'},
    ];

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Container(
          color: const Color(0xFF0B1215),
          child: Row(
            children: List.generate(
              navItems.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    _changeScreen();
                    setState(() {
                      _selectedIndex = index;
                      _isShowingSearch = false;
                      _isShowingNotifications = false;
                      _selectedPost = null;
                      if (index != 2) {
                        _selectedProfileSection = null;
                        _profileEditing = false;
                      }
                      if (index != 1) {
                        _selectedCommunity = null;
                      }
                    });
                  },
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedIndex == index
                            ? primaryCyan.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: _selectedIndex == index ? 1.1 : 1.0,
                            child: Icon(
                              navItems[index]['icon'] as IconData,
                              color: _selectedIndex == index
                                  ? primaryCyan
                                  : Colors.grey,
                              size: 23,
                            ),
                          ),
                          Text(
                            navItems[index]['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _selectedIndex == index
                                  ? primaryCyan
                                  : Colors.grey,
                              fontSize: 9,
                              fontWeight: _selectedIndex == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
