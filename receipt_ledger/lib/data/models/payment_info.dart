/// Payment information extracted from a notification
class PaymentInfo {
  final String? storeName;
  final double amount;
  final DateTime dateTime;
  final String? cardName;
  final String category;
  final String sourceApp;
  final String rawContent;

  PaymentInfo({
    this.storeName,
    required this.amount,
    required this.dateTime,
    this.cardName,
    required this.category,
    required this.sourceApp,
    required this.rawContent,
  });

  @override
  String toString() {
    return 'PaymentInfo(storeName: $storeName, amount: $amount, dateTime: $dateTime, category: $category)';
  }
}
