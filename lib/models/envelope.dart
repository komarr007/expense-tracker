class Envelope {
  final int? id;
  final String name;
  final String category;
  final double monthlyBudget;
  final DateTime createdAt;

  const Envelope({
    this.id,
    required this.name,
    required this.category,
    required this.monthlyBudget,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name':           name,
    'category':       category,
    'monthly_budget': monthlyBudget,
    'created_at':     createdAt.toIso8601String(),
  };

  factory Envelope.fromMap(Map<String, dynamic> m) => Envelope(
    id:            m['id'] as int?,
    name:          m['name'] as String,
    category:      m['category'] as String,
    monthlyBudget: (m['monthly_budget'] as num).toDouble(),
    createdAt:     DateTime.parse(m['created_at'] as String),
  );

  Envelope copyWith({
    int? id,
    String? name,
    String? category,
    double? monthlyBudget,
    DateTime? createdAt,
  }) => Envelope(
    id:            id            ?? this.id,
    name:          name          ?? this.name,
    category:      category      ?? this.category,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    createdAt:     createdAt     ?? this.createdAt,
  );
}
