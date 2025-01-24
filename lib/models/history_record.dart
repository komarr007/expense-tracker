class HistoryRecord {
  final int? id;
  final String name;
  final double amount;
  final DateTime spend_date;
  final DateTime created_at;
  final DateTime updated_at;
  final String? user_id;
  final String category;
  final DateTime deleted_at;

  HistoryRecord({
    this.id,
    required this.name,
    required this.amount,
    required this.spend_date,
    required this.created_at,
    required this.updated_at,
    this.user_id,
    required this.category,
    required this.deleted_at,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'spend_date': spend_date.toIso8601String(),
      'created_at': created_at.toIso8601String(),
      'updated_at': updated_at.toIso8601String(),
      'user_id': user_id,
      'category': category,
      'deleted_at': deleted_at.toIso8601String(),
    };
  }
}