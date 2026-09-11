class ManagedCatalogEntry {
  final String id;
  final String key;
  final String label;
  final String value;
  final int order;
  final bool active;
  final int revision;

  const ManagedCatalogEntry({
    required this.id,
    required this.key,
    required this.label,
    required this.value,
    required this.order,
    required this.active,
    this.revision = 1,
  });

  factory ManagedCatalogEntry.fromMap(Map<String, dynamic> map) {
    final rawOrder = map['order'];
    return ManagedCatalogEntry(
      id: (map['id'] ?? '').toString(),
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
      order: rawOrder is num
          ? rawOrder.toInt()
          : int.tryParse(rawOrder?.toString() ?? '') ?? 0,
      active: map['active'] == true,
      revision: (map['revision'] as num?)?.toInt() ?? 1,
    );
  }
}
