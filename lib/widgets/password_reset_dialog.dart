import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({
    super.key,
    required this.sendReset,
    this.initialEmail = '',
  });

  final Future<void> Function(String email) sendReset;
  final String initialEmail;

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _sent || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sendReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error) {
          FirebaseAuthException(code: 'too-many-requests') =>
            'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.',
          FirebaseAuthException(code: 'network-request-failed') =>
            'Verifique sua conexão e tente novamente.',
          FirebaseAuthException(code: 'invalid-email') =>
            'Confira o endereço de e-mail.',
          StateError() =>
            'Recuperação indisponível. O Firebase não está conectado.',
          _ => 'Não foi possível enviar. Tente novamente em instantes.',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(_sent ? 'Confira seu e-mail' : 'Recuperar senha'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: _sent
                ? const Text(
                    'Se houver uma conta com esse e-mail, você receberá um link para criar uma nova senha. Confira também a pasta de spam.',
                  )
                : Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            labelText: 'E-mail da conta',
                            prefixIcon: Icon(Icons.email_outlined),
                            filled: true,
                            border: InputBorder.none,
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Informe um e-mail válido.',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
        actions: [
          if (!_sent)
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : (_sent ? () => Navigator.pop(context) : _send),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_sent ? Icons.check : Icons.send_outlined),
            label: Text(
              _sent
                  ? 'Voltar ao login'
                  : (_busy ? 'Enviando...' : 'Enviar link'),
            ),
          ),
        ],
      ),
    );
  }
}
