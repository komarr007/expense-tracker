class NetWorthItem {
  static const List<String> assetTypes = [
    'bank', 'property', 'investment', 'vehicle', 'other',
  ];
  static const List<String> liabilityTypes = [
    'loan', 'credit card', 'mortgage', 'other',
  ];

  final int? id;
  final String name;
  final double value;
  final String type;
  final bool isAsset;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NetWorthItem({
    this.id,
    required this.name,
    required this.value,
    required this.type,
    required this.isAsset,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name':       name,
    'value':      value,
    'type':       type,
    'is_asset':   isAsset ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory NetWorthItem.fromMap(Map<String, dynamic> m) => NetWorthItem(
    id:        m['id'] as int?,
    name:      m['name'] as String,
    value:     (m['value'] as num).toDouble(),
    type:      m['type'] as String,
    isAsset:   (m['is_asset'] as int) == 1,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );

  NetWorthItem copyWith({
    int? id,
    String? name,
    double? value,
    String? type,
    bool? isAsset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NetWorthItem(
    id:        id        ?? this.id,
    name:      name      ?? this.name,
    value:     value     ?? this.value,
    type:      type      ?? this.type,
    isAsset:   isAsset   ?? this.isAsset,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
