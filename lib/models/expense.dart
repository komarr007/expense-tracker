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
    return {
      'name': name,
      'amount': amount,
      'spend_date': spend_date.toIso8601String(),
      'created_at': created_at.toIso8601String(),
      'updated_at': updated_at.toIso8601String(),
      'user_id': user_id,
      'category': category,
    };
  }
}
