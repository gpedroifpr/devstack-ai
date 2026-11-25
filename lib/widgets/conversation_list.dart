import 'package:flutter/material.dart';
import '../services/chat_conversation_service.dart';

class ConversationList extends StatelessWidget {
  final List<ChatConversation> conversations;
  final String selectedId;
  final bool enabled;
  final VoidCallback onNew;
  final ValueChanged<String> onSelect;
  const ConversationList({
    super.key,
    required this.conversations,
    required this.selectedId,
    required this.enabled,
    required this.onNew,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: enabled ? onNew : null,
            icon: const Icon(Icons.add),
            label: const Text('Nova conversa'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Text(
            'Recentes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nenhuma conversa salva.'),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final chat = conversations[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        selected: chat.id == selectedId,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .12),
                        title: Text(
                          chat.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                        ),
                        enabled: enabled,
                        onTap: () => onSelect(chat.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
