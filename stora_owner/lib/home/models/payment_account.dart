import 'dart:typed_data';
import '../../data/api/api_config.dart';

class PaymentAccount {
  final String? id;
  final String label;         // e.g., 'GCash', 'Maya', 'BPI', 'BDO'
  final String accountName;   // e.g., 'Juan Dela Cruz'
  final String accountNumber; // e.g., '0917 123 4567'
  final String? qrCodeUrl;    // uploaded QR image URL
  final bool isPrimary;       // whether this is marked as primary/default
  final bool isActive;        // whether this account is active and visible to customers

  // Local-only fields for pending uploads:
  final Uint8List? pendingQrBytes;
  final String? pendingQrFilename;
  final bool qrCleared;

  const PaymentAccount({
    this.id,
    this.label = '',
    this.accountName = '',
    this.accountNumber = '',
    this.qrCodeUrl,
    this.isPrimary = false,
    this.isActive = true,
    this.pendingQrBytes,
    this.pendingQrFilename,
    this.qrCleared = false,
  });

  bool get hasQr => !qrCleared && (pendingQrBytes != null || (qrCodeUrl != null && qrCodeUrl!.isNotEmpty));

  String get resolvedQrUrl {
    if (qrCodeUrl == null || qrCodeUrl!.isEmpty) return '';
    return ApiConfig.resolveMediaUrl(qrCodeUrl) ?? qrCodeUrl!;
  }

  PaymentAccount copyWith({
    String? id,
    String? label,
    String? accountName,
    String? accountNumber,
    String? qrCodeUrl,
    bool? isPrimary,
    bool? isActive,
    Uint8List? pendingQrBytes,
    String? pendingQrFilename,
    bool? qrCleared,
  }) {
    return PaymentAccount(
      id: id ?? this.id,
      label: label ?? this.label,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      isActive: isActive ?? this.isActive,
      pendingQrBytes: pendingQrBytes ?? this.pendingQrBytes,
      pendingQrFilename: pendingQrFilename ?? this.pendingQrFilename,
      qrCleared: qrCleared ?? this.qrCleared,
    );
  }

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    final rawQr = (json['qr_code_url'] ?? json['qr_code'])?.toString();
    return PaymentAccount(
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      isPrimary: json['is_primary'] == true,
      isActive: json['is_active'] != false,
      qrCodeUrl: (rawQr != null && rawQr.isNotEmpty) ? ApiConfig.resolveMediaUrl(rawQr) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'label': label,
    'account_name': accountName,
    'account_number': accountNumber,
    'is_primary': isPrimary,
    'is_active': isActive,
    if (qrCodeUrl != null) 'qr_code_url': qrCodeUrl,
    if (qrCleared) 'clear_qr': true,
  };

  /// Preset labels for common Philippine payment services
  static const List<String> presetLabels = [
    'GCash',
    'Maya',
    'BPI',
    'BDO',
    'UnionBank',
    'Metrobank',
    'LandBank',
    'GoTyme',
    'ShopeePay',
    'Other',
  ];
}
