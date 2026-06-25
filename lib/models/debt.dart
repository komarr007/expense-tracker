class Debt {
  final int? id;
  final String name;
  final double originalAmount;
  final double currentBalance;
  final double interestRate;
  final double? minimumPayment;
  final int? dueDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get paidOff => (originalAmount - currentBalance).clamp(0.0, originalAmount);
  double get progress => originalAmount > 0
      ? (paidOff / originalAmount).clamp(0.0, 1.0)
      : 0.0;

  const Debt({
    this.id,
    required this.name,
    required this.originalAmount,
    required this.currentBalance,
    this.interestRate = 0,
    this.minimumPayment,
    this.dueDay,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name':             name,
    'original_amount':  originalAmount,
    'current_balance':  currentBalance,
    'interest_rate':    interestRate,
    'minimum_payment':  minimumPayment,
    'due_day':          dueDay,
    'created_at':       createdAt.toIso8601String(),
    'updated_at':       updatedAt.toIso8601String(),
  };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
    id:              m['id'] as int?,
    name:            m['name'] as String,
    originalAmount:  (m['original_amount'] as num).toDouble(),
    currentBalance:  (m['current_balance'] as num).toDouble(),
    interestRate:    (m['interest_rate'] as num).toDouble(),
    minimumPayment:  m['minimum_payment'] != null ? (m['minimum_payment'] as num).toDouble() : null,
    dueDay:          m['due_day'] as int?,
    createdAt:       DateTime.parse(m['created_at'] as String),
    updatedAt:       DateTime.parse(m['updated_at'] as String),
  );

  Debt copyWith({
    int? id,
    String? name,
    double? originalAmount,
    double? currentBalance,
    double? interestRate,
    double? minimumPayment,
    int? dueDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Debt(
    id:             id             ?? this.id,
    name:           name           ?? this.name,
    originalAmount: originalAmount ?? this.originalAmount,
    currentBalance: currentBalance ?? this.currentBalance,
    interestRate:   interestRate   ?? this.interestRate,
    minimumPayment: minimumPayment ?? this.minimumPayment,
    dueDay:         dueDay         ?? this.dueDay,
    createdAt:      createdAt      ?? this.createdAt,
    updatedAt:      updatedAt      ?? this.updatedAt,
  );
}
