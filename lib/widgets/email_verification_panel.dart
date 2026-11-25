import '../theme/app_theme.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationPanel extends StatefulWidget {
  final String email;
  final Future<bool> Function() refresh;
  final Future<void> Function() send;

  const EmailVerificationPanel({
    super.key,
    required this.email,
    required this.refresh,
    required this.send,
  });

  @override
  State<EmailVerificationPanel> createState() => _EmailVerificationPanelState();
}

class _EmailVerificationPanelState extends State<EmailVerificationPanel> {
  bool? _verified;
  bool _busy = false;
  bool _sent = false;
  String? _message;
  bool _error = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde um pouco antes de reenviar.';
        case 'network-request-failed':
          return 'Sem conexão. Verifique sua internet e tente novamente.';
        case 'requires-recent-login':
        case 'user-token-expired':
        case 'user-disabled':
          return 'Entre novamente na sua conta para continuar.';
      }
    }
    return 'Não foi possível concluir. Tente novamente em instantes.';
  }

  Future<void> _check({bool manual = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final verified = await widget.refresh();
      if (!mounted) return;
      setState(() {
        _verified = verified;
        if (manual && !verified) _message = 'Confirmação ainda pendente.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _errorMessage(error);
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await widget.send();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _seconds = 60;
        _message = 'Link enviado. Confira também a pasta de spam.';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _seconds--);
        if (_seconds <= 0) timer.cancel();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _errorMessage(error);
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.color(context, Color(0xFF43DDE7));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _verified == true
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                color: _verified == true
                    ? AppPalette.color(context, Colors.greenAccent)
                    : AppPalette.color(context, Colors.amber),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _verified == true
                      ? 'E-mail confirmado'
                      : _verified == false
                      ? 'E-mail não confirmado'
                      : 'Verificação de e-mail',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.email,
            style: TextStyle(color: AppPalette.color(context, Colors.white70)),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _error
                        ? AppPalette.color(context, Colors.orangeAccent)
                        : AppPalette.color(context, Colors.white70),
                  ),
                ),
              ),
            ),
          if (_verified != true) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (_verified == false)
                  OutlinedButton.icon(
                    onPressed: _busy || _seconds > 0 ? null : _send,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                      _seconds > 0
                          ? 'Reenviar em ${_seconds}s'
                          : _sent
                          ? 'Reenviar confirmação'
                          : 'Enviar confirmação',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _check(manual: true),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _verified == null ? 'Tentar novamente' : 'Já confirmei',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
