class Transaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final bool isRecurring;
  final String? recurrenceFrequency;
  final DateTime? nextRecurrenceDate;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.isRecurring,
    this.recurrenceFrequency,
    this.nextRecurrenceDate,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as double,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceFrequency: json['recurrence_frequency'] as String?,
      nextRecurrenceDate: json['next_recurrence_date'] != null
          ? DateTime.parse(json['next_recurrence_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'is_recurring': isRecurring,
      'recurrence_frequency': recurrenceFrequency,
      'next_recurrence_date': nextRecurrenceDate?.toIso8601String(),
    };
  }
}
