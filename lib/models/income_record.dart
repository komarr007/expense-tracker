class IncomeRecord {
  static const List<String> categories = <String>[
    'salary',
    'freelance',
    'business',
    'investment return',
    'bonus',
    'gift',
    'others',
  ];

  final int? id;
  final String name;
  final double amount;
  final DateTime income_date;
  final String category;
  final String? notes;
  final DateTime created_at;

  IncomeRecord({
    this.id,
    required this.name,
    required this.amount,
    required this.income_date,
    required this.category,
    this.notes,
    DateTime? created_at,
  }) : created_at = created_at ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name':        name,
      'amount':      amount,
      'income_date': income_date.toIso8601String(),
      'category':    category,
      'notes':       notes,
      'created_at':  created_at.toIso8601String(),
    };
  }

  factory IncomeRecord.fromMap(Map<String, dynamic> map) {
    return IncomeRecord(
      id:          map['id'],
      name:        map['name'],
      amount:      map['amount'],
      income_date: DateTime.parse(map['income_date']),
      category:    map['category'] ?? 'others',
      notes:       map['notes'] as String?,
      created_at:  DateTime.parse(map['created_at']),
    );
  }

  IncomeRecord copyWith({
    int? id,
    String? name,
    double? amount,
    DateTime? income_date,
    String? category,
    String? notes,
    DateTime? created_at,
  }) {
    return IncomeRecord(
      id:          id          ?? this.id,
      name:        name        ?? this.name,
      amount:      amount      ?? this.amount,
      income_date: income_date ?? this.income_date,
      category:    category    ?? this.category,
      notes:       notes       ?? this.notes,
      created_at:  created_at  ?? this.created_at,
    );
  }
}
