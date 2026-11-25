import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AIResponseBody extends StatelessWidget {
  const AIResponseBody({
    super.key,
    required this.text,
    this.isRevealing = false,
  });

  final String text;
  final bool isRevealing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body = TextStyle(color: colors.onSurface, fontSize: 15, height: 1.65);
    TextStyle heading(double size) =>
        body.copyWith(fontSize: size, height: 1.3, fontWeight: FontWeight.w700);

    final markdown = MarkdownBody(
      data: text,
      // EditableText-backed Markdown can lose its paint while text and scroll
      // offsets change together on web. Keep paragraphs as ordinary RichText.
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        h1: heading(24),
        h2: heading(21),
        h3: heading(18),
        h4: heading(16),
        h5: heading(16),
        h6: heading(16),
        h1Padding: const EdgeInsets.only(top: 16, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 14, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 10, bottom: 2),
        blockSpacing: 16,
        listBullet: body.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        listIndent: 24,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.6,
          color: colors.onSurface,
          backgroundColor: colors.primary.withValues(alpha: .07),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.onSurface.withValues(alpha: .10)),
        ),
        blockquote: body,
        blockquotePadding: const EdgeInsets.all(14),
        blockquoteDecoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .05),
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        tableBody: body,
        tableCellsPadding: const EdgeInsets.all(8),
        tableBorder: TableBorder.all(
          color: colors.onSurface.withValues(alpha: .15),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.onSurface.withValues(alpha: .12)),
          ),
        ),
      ),
      // Model-generated image URLs must not trigger unsolicited network requests.
      imageBuilder: (_, title, alt) =>
          Text(alt ?? title ?? 'Imagem', style: body),
      onTapLink: (_, href, _) {
        if (href == null) return;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Link da resposta'),
            content: SelectableText(href),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fechar'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: href));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar link'),
              ),
            ],
          ),
        );
      },
    );
    return isRevealing ? markdown : SelectionArea(child: markdown);
  }
}
