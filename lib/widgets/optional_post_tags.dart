import 'package:flutter/material.dart';

class OptionalPostTags extends StatelessWidget {
  const OptionalPostTags({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ChoiceChip(
        label: const Text('Sem tag'),
        selected: selected.isEmpty,
        onSelected: (_) => onChanged(<String>{}),
      ),
      for (final tag in options.where((tag) => tag != 'Todos'))
        FilterChip(
          label: Text(tag),
          selected: selected.contains(tag),
          onSelected: (value) {
            final next = {...selected};
            if (value) {
              next.add(tag);
            } else {
              next.remove(tag);
            }
            onChanged(next);
          },
        ),
    ],
  );
}
