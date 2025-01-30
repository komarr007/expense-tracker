class Expense {
  final int? id;
  final String name;
  final double amount;
  final DateTime spend_date;
  final DateTime created_at;
  final DateTime updated_at;
  final String? user_id;
  final String category;  // New field

  Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.spend_date,
    DateTime? created_at,
    DateTime? updated_at,
    this.user_id,
    required this.category, // Add category to constructor
  })  : created_at = created_at ?? DateTime.now(),
        updated_at = updated_at ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'spend_date': spend_date.toIso8601String(),
      'created_at': created_at.toIso8601String(),
      'updated_at': updated_at.toIso8601String(),
      'user_id': user_id,
      'category': category,
    };
  }

  Expense copyWith({
    int? id,
    String? name,
    double? amount,
    DateTime? spend_date,
    DateTime? created_at,
    DateTime? updated_at,
    String? user_id,
    String? category,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      spend_date: spend_date ?? this.spend_date,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
      user_id: user_id ?? this.user_id,
      category: category ?? this.category,
    );
  }
}
