import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppearanceButton extends StatelessWidget {
  const AppearanceButton({super.key, this.onSettings});
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return PopupMenuButton<String>(
      tooltip: 'Aparência e opções',
      icon: Icon(light ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onSelected: (value) async {
        if (value == 'settings') {
          onSettings?.call();
          return;
        }
        try {
          await ThemePreference.instance.select(
            value == 'light' ? ThemeMode.light : ThemeMode.dark,
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Não foi possível salvar a aparência. Tente novamente.',
                ),
              ),
            );
          }
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'light',
          checked: light,
          child: const Text('Tema claro'),
        ),
        CheckedPopupMenuItem(
          value: 'dark',
          checked: !light,
          child: const Text('Tema escuro'),
        ),
        if (onSettings != null) const PopupMenuDivider(),
        if (onSettings != null)
          const PopupMenuItem(
            value: 'settings',
            child: Text('Configurações da IA'),
          ),
      ],
    );
  }
}
