import '../../home/utils/date_utils.dart';

class PaymentProofInfo {
  final int? id;
  final String referenceNumber;
  final String amount;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const PaymentProofInfo({
    this.id,
    required this.referenceNumber,
    required this.amount,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory PaymentProofInfo.fromJson(Map<String, dynamic> json) {
    return PaymentProofInfo(
      id: json['id'] as int?,
      referenceNumber: (json['reference_number'] as String?) ?? '',
      amount: (json['amount'] as String?) ?? '0.00',
      status: (json['status'] as String?) ?? 'pending',
      submittedAt: json['submitted_at'] != null
          ? parseApiDateTime(json['submitted_at'] as String)
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? parseApiDateTime(json['reviewed_at'] as String)
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

class AccountStatus {
  final bool isPremium;
  final DateTime? premiumUntil;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final int productCount;
  final int productLimit;
  final int daysLeft;
  final bool canAddProduct;
  final double monthlyPrice;
  final String gcashNumber;
  final String gcashName;
  final PaymentProofInfo? latestPaymentProof;

  const AccountStatus({
    required this.isPremium,
    this.premiumUntil,
    this.trialStartedAt,
    this.trialEndsAt,
    required this.productCount,
    required this.productLimit,
    required this.daysLeft,
    required this.canAddProduct,
    this.monthlyPrice = 70.0,
    this.gcashNumber = '0917 000 0070',
    this.gcashName = 'STORA Admin',
    this.latestPaymentProof,
  });

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    final proofJson = json['latest_payment_proof'] as Map<String, dynamic>?;
    return AccountStatus(
      isPremium: json['is_premium'] as bool? ?? false,
      premiumUntil: json['premium_until'] != null
          ? parseApiDateTime(json['premium_until'] as String)
          : null,
      trialStartedAt: json['trial_started_at'] != null
          ? parseApiDateTime(json['trial_started_at'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? parseApiDateTime(json['trial_ends_at'] as String)
          : null,
      productCount: _asInt(json['product_count'], 0),
      productLimit: _asInt(json['product_limit'], 20),
      daysLeft: _asInt(json['days_left'], 0),
      canAddProduct: json['can_add_product'] as bool? ?? false,
      monthlyPrice: _asDouble(json['monthly_price'], 70.0),
      gcashNumber: (json['gcash_number'] as String?) ?? '0917 000 0070',
      gcashName: (json['gcash_name'] as String?) ?? 'STORA Admin',
      latestPaymentProof: proofJson != null ? PaymentProofInfo.fromJson(proofJson) : null,
    );
  }

  static const AccountStatus fallback = AccountStatus(
    isPremium: false,
    productCount: 0,
    productLimit: 20,
    daysLeft: 14,
    canAddProduct: true,
    monthlyPrice: 70.0,
    gcashNumber: '0917 000 0070',
    gcashName: 'STORA Admin',
  );
}

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, double fallback) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

