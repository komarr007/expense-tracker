class RecurringExpense {
  static const List<String> frequencies = <String>[
    'daily',
    'weekly',
    'monthly',
  ];

  final int? id;
  final String name;
  final double amount;
  final String category;
  final String? notes;
  final String frequency;
  final DateTime next_due;
  final DateTime created_at;

  RecurringExpense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    this.notes,
    required this.frequency,
    required this.next_due,
    DateTime? created_at,
  }) : created_at = created_at ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name':       name,
      'amount':     amount,
      'category':   category,
      'notes':      notes,
      'frequency':  frequency,
      'next_due':   next_due.toIso8601String(),
      'created_at': created_at.toIso8601String(),
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id:        map['id'],
      name:      map['name'],
      amount:    map['amount'],
      category:  map['category'] ?? 'others',
      notes:     map['notes'] as String?,
      frequency: map['frequency'] ?? 'monthly',
      next_due:  DateTime.parse(map['next_due']),
      created_at: DateTime.parse(map['created_at']),
    );
  }

  RecurringExpense copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    String? notes,
    String? frequency,
    DateTime? next_due,
    DateTime? created_at,
  }) {
    return RecurringExpense(
      id:         id         ?? this.id,
      name:       name       ?? this.name,
      amount:     amount     ?? this.amount,
      category:   category   ?? this.category,
      notes:      notes      ?? this.notes,
      frequency:  frequency  ?? this.frequency,
      next_due:   next_due   ?? this.next_due,
      created_at: created_at ?? this.created_at,
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':   return 'Daily';
      case 'weekly':  return 'Weekly';
      case 'monthly': return 'Monthly';
      default:        return frequency;
    }
  }
}
