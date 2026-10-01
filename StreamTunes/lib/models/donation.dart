class Donation {
  final String id;
  final String artistId;
  final String artistName;
  final double amount;
  final String currency;
  final String? message;
  final String paymentMethod;
  final DateTime timestamp;

  Donation({
    required this.id,
    required this.artistId,
    required this.artistName,
    required this.amount,
    this.currency = 'ARS',
    this.message,
    required this.paymentMethod,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedAmount => '\$$currency ${amount.toStringAsFixed(0)}';
}
