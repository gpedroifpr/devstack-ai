import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../models/post_update.dart';

class PostEditorDialog extends StatefulWidget {
  final String title;
  final String description;
  final String code;
  final Future<void> Function(PostUpdate) onSave;

  const PostEditorDialog({
    super.key,
    required this.title,
    required this.description,
    required this.code,
    required this.onSave,
  });

  @override
  State<PostEditorDialog> createState() => _PostEditorDialogState();
}

class _PostEditorDialogState extends State<PostEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title);
  late final _description = TextEditingController(text: widget.description);
  late final _code = TextEditingController(text: widget.code);
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        PostUpdate(
          title: _title.text,
          description: _description.text,
          code: _code.text,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Seu texto foi mantido; tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cyan = AppPalette.color(context, Color(0xFF43DDE7));
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: AppPalette.color(context, const Color(0xFF162126)),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Editar publicação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _field('Título', _title, min: 6, max: 160),
                  const SizedBox(height: 16),
                  _field(
                    'Descrição',
                    _description,
                    min: 12,
                    max: 10000,
                    lines: 4,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Código (opcional)',
                    _code,
                    min: 0,
                    max: 20000,
                    lines: 4,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: AppPalette.color(
                              context,
                              Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _saving ? 'Salvando...' : 'Salvar alterações',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: cyan,
                          foregroundColor: AppPalette.color(
                            context,
                            Colors.black,
                          ),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required int min,
    required int max,
    int lines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      minLines: lines,
      maxLines: lines == 1 ? 2 : 8,
      style: TextStyle(color: AppPalette.color(context, Colors.white)),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppPalette.color(context, const Color(0xFF0F171A)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        final length = (value ?? '').trim().length;
        if (length < min) return 'Use pelo menos $min caracteres.';
        if ((value ?? '').length > max) return 'Limite de $max caracteres.';
        return null;
      },
    );
  }
}
