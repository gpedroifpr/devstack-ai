import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_database_service.dart';
import '../widgets/password_reset_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/appearance_button.dart';

class AuthScreen extends StatefulWidget {
  final ValueChanged<LocalAuthUser> onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AppDatabaseService _databaseService = AppDatabaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  Color get _primaryCyan => AppPalette.color(context, const Color(0xFF4EE2EC));
  Color get _cardColor => AppPalette.color(context, const Color(0xFF162126));

  bool _isRegisterMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showWelcome = true;
  String? _formError;

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      final result = await _databaseService.signInWithGoogle();
      if (!mounted) return;
      if (result.isSuccess && result.user != null) {
        widget.onAuthenticated(result.user!);
      } else {
        _showFormError(result.error ?? 'Não foi possível entrar com Google.');
      }
    } catch (_) {
      if (mounted) {
        _showFormError('Não foi possível entrar com Google. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final validationError = _validateFields();
    if (validationError != null) {
      _showFormError(validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      final AuthResult result;

      if (_isRegisterMode) {
        result = await _databaseService.registerUser(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        result = await _databaseService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.isSuccess && result.user != null) {
        widget.onAuthenticated(result.user!);
        return;
      }

      _showFormError(result.error ?? 'Não foi possível continuar.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showFormError('Não foi possível continuar. Tente novamente.');
    }
  }

  String? _validateFields() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isRegisterMode && name.length < 3) {
      _nameFocusNode.requestFocus();
      return 'Informe um nome com pelo menos 3 caracteres.';
    }

    if (!email.contains('@') || !email.contains('.')) {
      _emailFocusNode.requestFocus();
      return 'Informe um e-mail válido.';
    }

    if (password.length < 6) {
      _passwordFocusNode.requestFocus();
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }

    return null;
  }

  void _showFormError(String message) {
    setState(() {
      _formError = message;
      _isLoading = false;
    });

    if (message.toLowerCase().contains('senha')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _passwordFocusNode.requestFocus();
        _passwordController.selection = TextSelection.collapsed(
          offset: _passwordController.text.length,
        );
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppPalette.color(context, Colors.redAccent),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearFormError() {
    if (_formError == null) return;

    setState(() {
      _formError = null;
    });
  }

  void _continueAsGuest() {
    if (_isLoading) return;
    widget.onAuthenticated(LocalAuthUser.guest());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.color(context, const Color(0xFF0B1215)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _showWelcome ? 980 : 460),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showWelcome
                    ? _buildWelcomeContent()
                    : _buildAuthFormContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader({bool centered = false}) {
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(Icons.psychology, color: _primaryCyan, size: 26),
        const SizedBox(width: 8),
        Text(
          'DevStack',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppPalette.color(context, Colors.white),
          ),
        ),
        Text(
          ' AI',
          style: TextStyle(
            color: _primaryCyan,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        const AppearanceButton(),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return LayoutBuilder(
      key: const ValueKey('welcome'),
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 760;

        return Container(
          padding: EdgeInsets.all(isWide ? 28 : 18),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildWelcomeHero()),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: _buildWelcomeActions()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWelcomeHero(),
                    const SizedBox(height: 18),
                    _buildWelcomeActions(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWelcomeFeature(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.color(context, Colors.white).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.color(
            context,
            Colors.white,
          ).withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _primaryCyan.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryCyan, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppPalette.color(context, Colors.grey.shade100),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandHeader(),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _primaryCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _primaryCyan.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: _primaryCyan, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Comunidade, dúvidas e IA em um só lugar',
                  style: TextStyle(
                    color: AppPalette.color(context, Colors.grey.shade100),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Estude programação com uma rede feita para tirar dúvidas.',
          style: GoogleFonts.poppins(
            color: AppPalette.color(context, Colors.white),
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Compartilhe suas dúvidas, explore soluções e aprenda com a comunidade.',
          style: TextStyle(
            color: AppPalette.color(context, Colors.grey.shade400),
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildWelcomeMetric('IA', 'apoio nas dúvidas'),
            _buildWelcomeMetric('Feed', 'posts e exemplos'),
            _buildWelcomeMetric('Comunidades', 'estudo em grupo'),
          ],
        ),
        const SizedBox(height: 24),
        _buildHeroPreviewCard(),
      ],
    );
  }

  Widget _buildWelcomeMetric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.color(context, const Color(0xFF0C1417)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.color(
            context,
            Colors.white,
          ).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: _primaryCyan,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: AppPalette.color(context, Colors.grey.shade500),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.color(context, const Color(0xFF0A1114)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppPalette.color(
            context,
            Colors.white,
          ).withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.color(
                    context,
                    const Color(0xFF2F8F83),
                  ).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.terminal_rounded,
                  color: AppPalette.color(context, Color(0xFF70E6C6)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dúvida em destaque',
                      style: TextStyle(
                        color: AppPalette.color(context, Colors.grey.shade200),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Flutter + Firebase',
                      style: TextStyle(
                        color: AppPalette.color(context, Colors.grey.shade500),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.auto_awesome, color: _primaryCyan, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Como salvo uma dúvida no banco e mostro no feed?',
            style: GoogleFonts.poppins(
              color: AppPalette.color(context, Colors.white),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.color(context, const Color(0xFF101A1E)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'A IA pode resumir o erro, sugerir próximos passos e transformar a dúvida em post para a comunidade.',
              style: TextStyle(
                color: AppPalette.color(context, Colors.grey.shade300),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeActions() {
    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _primaryCyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.auto_awesome, color: _primaryCyan, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            'Entre no DevStack AI',
            style: GoogleFonts.poppins(
              color: AppPalette.color(context, Colors.white),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie sua conta para salvar histórico, publicar dúvidas e continuar estudando de onde parou.',
            style: TextStyle(
              color: AppPalette.color(context, Colors.grey.shade400),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _buildWelcomeFeature(Icons.psychology_outlined, 'Chat com IA'),
          const SizedBox(height: 9),
          _buildWelcomeFeature(Icons.forum_outlined, 'Feed de dúvidas'),
          const SizedBox(height: 9),
          _buildWelcomeFeature(Icons.groups_2_outlined, 'Comunidades dev'),
          const SizedBox(height: 22),
          _buildWelcomeActionButton(
            label: 'Criar conta grátis',
            icon: Icons.arrow_forward_rounded,
            filled: true,
            onPressed: () {
              setState(() {
                _isRegisterMode = true;
                _showWelcome = false;
                _formError = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildWelcomeActionButton(
            label: 'Entrar na minha conta',
            icon: Icons.login_rounded,
            onPressed: () {
              setState(() {
                _isRegisterMode = false;
                _showWelcome = false;
                _formError = null;
              });
            },
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _continueAsGuest,
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.color(context, Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Explorar sem cadastro'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Icon(icon, size: 18),
      ],
    );

    if (filled) {
      return SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryCyan,
            foregroundColor: AppPalette.color(context, Colors.black),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.color(context, Colors.grey.shade100),
          side: BorderSide(
            color: AppPalette.color(
              context,
              Colors.white,
            ).withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildAuthFormContent() {
    return Column(
      key: const ValueKey('auth-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandHeader(),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _showWelcome = true;
                    _formError = null;
                  });
                },
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.color(context, Colors.grey.shade400),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Voltar'),
        ),
        const SizedBox(height: 12),
        Text(
          _isRegisterMode ? 'Crie sua conta' : 'Entre na sua conta',
          style: GoogleFonts.poppins(
            color: AppPalette.color(context, Colors.white),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegisterMode
              ? 'Salve dúvidas, publique no feed e acompanhe seu progresso.'
              : 'Continue de onde parou no seu ambiente de estudos.',
          style: TextStyle(
            color: AppPalette.color(context, Colors.grey.shade400),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryCyan.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              if (kIsWeb) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.color(context, Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Continuar com Google'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('ou use seu e-mail'),
                ),
              ],
              if (_isRegisterMode) ...[
                _buildField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  label: 'Nome',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
              ],
              _buildField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                label: 'E-mail',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: 'Senha',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppPalette.color(context, Colors.grey),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (!_isRegisterMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => PasswordResetDialog(
                              initialEmail: _emailController.text.trim(),
                              sendReset: _databaseService.sendPasswordReset,
                            ),
                          ),
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.color(
                      context,
                      Colors.redAccent,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppPalette.color(context, Colors.redAccent),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formError!,
                          style: TextStyle(
                            color: AppPalette.color(context, Colors.redAccent),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildBackendStatusBanner(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryCyan,
                    foregroundColor: AppPalette.color(context, Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.color(context, Colors.black),
                          ),
                        )
                      : Text(
                          _isRegisterMode ? 'Cadastrar' : 'Entrar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isRegisterMode = !_isRegisterMode;
                          _formError = null;
                        });
                      },
                child: Text(
                  _isRegisterMode ? 'Já tenho conta' : 'Criar nova conta',
                  style: TextStyle(
                    color: _primaryCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppPalette.color(
                        context,
                        Colors.white,
                      ).withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ou',
                      style: TextStyle(
                        color: AppPalette.color(context, Colors.grey.shade500),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppPalette.color(
                        context,
                        Colors.white,
                      ).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryCyan,
                    side: BorderSide(
                      color: _primaryCyan.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text(
                    'Continuar sem conta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackendStatusBanner() {
    final isConnected = _databaseService.isUsingFirebase;
    final color = isConnected
        ? AppPalette.color(context, Colors.greenAccent)
        : AppPalette.color(context, Colors.orangeAccent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isConnected
                ? Icons.cloud_done_rounded
                : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _databaseService.backendStatusMessage,
              style: TextStyle(
                color: AppPalette.color(context, Colors.grey.shade200),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppPalette.color(context, Colors.grey.shade300),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppPalette.color(context, const Color(0xFF0F171A)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.color(
                context,
                Colors.white,
              ).withValues(alpha: 0.06),
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !_isLoading,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: (_) => _clearFormError(),
            onSubmitted: onSubmitted,
            style: TextStyle(color: AppPalette.color(context, Colors.white)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _primaryCyan),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
