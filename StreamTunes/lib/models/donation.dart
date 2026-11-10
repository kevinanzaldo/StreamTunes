class Donation {
  final String id;
  final String artistId;
  final String artistName;
  final double amount;
  final String currency;
  final String? message;
  final String paymentMethod;
  final DateTime timestamp;
  final String? donorName;
  final bool isPublic;

  Donation({
    required this.id,
    required this.artistId,
    required this.artistName,
    required this.amount,
    this.currency = 'ARS',
    this.message,
    required this.paymentMethod,
    DateTime? timestamp,
    this.donorName,
    this.isPublic = true,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedAmount => '\$$currency ${amount.toStringAsFixed(0)}';

  Donation copyWith({
    String? id,
    String? artistId,
    String? artistName,
    double? amount,
    String? currency,
    String? message,
    String? paymentMethod,
    DateTime? timestamp,
    String? donorName,
    bool? isPublic,
  }) {
    return Donation(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      message: message ?? this.message,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
      donorName: donorName ?? this.donorName,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
