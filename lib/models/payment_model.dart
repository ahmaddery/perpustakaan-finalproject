class Payment {
  final int id;
  final int userId;
  final String? paymentCategory;
  final String? referenceId;
  final int? loanId;
  final int? bookId;
  final int daysLate;
  final String? externalId;
  final String? merchantName;
  final String? merchantProfilePictureUrl;
  final double amount;
  final String? payerEmail;
  final String? description;
  final DateTime? expiryDate;
  final String? invoiceUrl;
  final String status;
  final String currency;
  final int quantity;
  final double paidAmount;
  final String? bankCode;
  final DateTime? paidAt;
  final String? paymentChannel;
  final String? paymentDestination;
  final String? paymentId;
  final bool isHigh;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.userId,
    this.paymentCategory,
    this.referenceId,
    this.loanId,
    this.bookId,
    required this.daysLate,
    this.externalId,
    this.merchantName,
    this.merchantProfilePictureUrl,
    required this.amount,
    this.payerEmail,
    this.description,
    this.expiryDate,
    this.invoiceUrl,
    required this.status,
    required this.currency,
    required this.quantity,
    required this.paidAmount,
    this.bankCode,
    this.paidAt,
    this.paymentChannel,
    this.paymentDestination,
    this.paymentId,
    required this.isHigh,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      userId: json['user_id'],
      paymentCategory: json['payment_category'],
      referenceId: json['reference_id'],
      loanId: json['loan_id'],
      bookId: json['book_id'],
      daysLate: json['days_late'] ?? 0,
      externalId: json['external_id'],
      merchantName: json['merchant_name'],
      merchantProfilePictureUrl: json['merchant_profile_picture_url'],
      amount: double.parse(json['amount'].toString()),
      payerEmail: json['payer_email'],
      description: json['description'],
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date']) 
          : null,
      invoiceUrl: json['invoice_url'],
      status: json['status'],
      currency: json['currency'],
      quantity: json['quantity'] ?? 1,
      paidAmount: double.parse(json['paid_amount'].toString()),
      bankCode: json['bank_code'],
      paidAt: json['paid_at'] != null 
          ? DateTime.parse(json['paid_at']) 
          : null,
      paymentChannel: json['payment_channel'],
      paymentDestination: json['payment_destination'],
      paymentId: json['payment_id'],
      isHigh: json['is_high'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'payment_category': paymentCategory,
      'reference_id': referenceId,
      'loan_id': loanId,
      'book_id': bookId,
      'days_late': daysLate,
      'external_id': externalId,
      'merchant_name': merchantName,
      'merchant_profile_picture_url': merchantProfilePictureUrl,
      'amount': amount,
      'payer_email': payerEmail,
      'description': description,
      'expiry_date': expiryDate?.toIso8601String(),
      'invoice_url': invoiceUrl,
      'status': status,
      'currency': currency,
      'quantity': quantity,
      'paid_amount': paidAmount,
      'bank_code': bankCode,
      'paid_at': paidAt?.toIso8601String(),
      'payment_channel': paymentChannel,
      'payment_destination': paymentDestination,
      'payment_id': paymentId,
      'is_high': isHigh,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  double get remainingAmount => amount - paidAmount;
  double get paymentProgress => amount > 0 ? (paidAmount / amount) * 100 : 0;
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
}