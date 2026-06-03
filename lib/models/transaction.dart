class TransactionModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String payerId;
  final Map<String, double> splitDetails; // userId: amount
  final DateTime date;
  final String category;

  TransactionModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.splitDetails,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'payerId': payerId,
      'splitDetails': splitDetails,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      payerId: map['payerId'] ?? '',
      splitDetails: Map<String, double>.from(map['splitDetails'] ?? {}),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'General',
    );
  }
}
