import 'package:flutter/material.dart';

class ScheduleSelectorOption {
  final String id;
  final String label;
  final String searchText;

  const ScheduleSelectorOption({
    required this.id,
    required this.label,
    this.searchText = '',
  });
}

class SearchableScheduleSelector extends StatelessWidget {
  final String label;
  final String hint;
  final String searchHint;
  final String emptyMessage;
  final String? selectedId;
  final List<ScheduleSelectorOption> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const SearchableScheduleSelector({
    super.key,
    required this.label,
    required this.hint,
    required this.searchHint,
    required this.emptyMessage,
    required this.selectedId,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  ScheduleSelectorOption? get _selected {
    for (final option in options) {
      if (option.id == selectedId) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _ScheduleSearchDialog(
        title: label,
        searchHint: searchHint,
        emptyMessage: emptyMessage,
        selectedId: selectedId,
        options: options,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      button: true,
      label: selected == null ? hint : '$label: ${selected.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => _open(context) : null,
        child: InputDecorator(
          isEmpty: selected == null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            enabled: enabled,
          ),
          child: selected == null
              ? const SizedBox(height: 24)
              : Text(
                  selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

class _ScheduleSearchDialog extends StatefulWidget {
  final String title;
  final String searchHint;
  final String emptyMessage;
  final String? selectedId;
  final List<ScheduleSelectorOption> options;

  const _ScheduleSearchDialog({
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.selectedId,
    required this.options,
  });

  @override
  State<_ScheduleSearchDialog> createState() => _ScheduleSearchDialogState();
}

class _ScheduleSearchDialogState extends State<_ScheduleSearchDialog> {
  String _query = '';

  String _normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u');

  @override
  Widget build(BuildContext context) {
    final query = _normalized(_query.trim());
    final filtered = widget.options.where((option) {
      final searchable = _normalized('${option.label} ${option.searchText}');
      return query.isEmpty || searchable.contains(query);
    }).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(widget.emptyMessage))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        return ListTile(
                          selected: option.id == widget.selectedId,
                          leading: Icon(
                            option.id == widget.selectedId
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                          title: Text(option.label),
                          onTap: () => Navigator.of(context).pop(option.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
