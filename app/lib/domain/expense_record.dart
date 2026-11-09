/// Daily operating expense (`s.expenses`).
class ExpenseRecord {
  const new({
    required this.id,
    required this.date,
    required this.at,
    required this.typeId,
    required this.amount,
    this.note = '',
  });
  factory fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id'] as String,
    date: json['date'] as String,
    at: json['at'] as String,
    typeId: json['typeId'] as String,
    amount: (json['amount'] as num).toInt(),
    note: (json['note'] as String?) ?? '',
  );
  final String id;
  final String date;
  final String at;
  final String typeId;
  final int amount;
  final String note;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date,
    'at': at,
    'typeId': typeId,
    'amount': amount,
    'note': note,
  };
}
