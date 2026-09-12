import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';

class CustomerOrderItem {
  final int? id;
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  CustomerOrderItem({
    this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;
  String get formattedUnitPrice => '₱${unitPrice.toStringAsFixed(2)}';
  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    return CustomerOrderItem(
      id: json['id'] as int?,
      productId: json['product'] as int?,
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (productId != null) 'product': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice.toStringAsFixed(2),
    };
  }
}

class CustomerOrder {
  final int id;
  final int ownerId;
  final String storeName;
  final String? storeAvatarUrl;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String notes;
  final String status;
  final String? declineReason;
  final String? counterNotes;
  final double? counterPrice;
  final double totalAmount;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<CustomerOrderItem> items;
  final String? latestMessage;
  final bool latestMessageIsMe;
  final int unreadMessageCount;
  final DateTime? latestMessageAt;
  final bool latestMessageIsUnsent;

  CustomerOrder({
    required this.id,
    required this.ownerId,
    this.storeName = '',
    this.storeAvatarUrl,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.notes,
    required this.status,
    this.declineReason,
    this.counterNotes,
    this.counterPrice,
    required this.totalAmount,
    this.createdAt,
    this.expiresAt,
    required this.items,
    this.latestMessage,
    this.latestMessageIsMe = false,
    this.unreadMessageCount = 0,
    this.latestMessageAt,
    this.latestMessageIsUnsent = false,
  });

  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';
  String get formattedCounterPrice => counterPrice != null ? '₱${counterPrice!.toStringAsFixed(2)}' : '';
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'ready':
        return 'Ready for Pickup';
      case 'accepted':
        return 'Accepted (Preparing)';
      case 'declined':
        return 'Declined';
      case 'auto_declined':
        return 'Auto-Declined';
      case 'counter_offer':
        return 'Counter-Offer';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'ready':
        return AppColors.success;
      case 'accepted':
        return AppColors.primary;
      case 'declined':
      case 'auto_declined':
        return AppColors.danger;
      case 'counter_offer':
        return AppColors.primary;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  Color get statusBgColor {
    switch (status.toLowerCase()) {
      case 'ready':
        return AppColors.successBg;
      case 'accepted':
        return AppColors.primary.withValues(alpha: 0.15);
      case 'declined':
      case 'auto_declined':
        return AppColors.dangerBg;
      case 'counter_offer':
        return AppColors.cardElevated;
      case 'pending':
      default:
        return AppColors.warningBg;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'ready':
        return Icons.done_all_rounded;
      case 'accepted':
        return Icons.shopping_bag_outlined;
      case 'declined':
      case 'auto_declined':
        return Icons.cancel_outlined;
      case 'counter_offer':
        return Icons.local_offer_outlined;
      case 'pending':
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String get formattedDate {
    if (createdAt == null) return '';
    final dt = toPht(createdAt!);
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return CustomerOrder(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      ownerId: json['owner'] is int ? json['owner'] as int : (int.tryParse(json['owner']?.toString() ?? '0') ?? 0),
      storeName: (json['store_name'] as String?) ?? '',
      storeAvatarUrl: json['store_avatar_url'] as String?,
      customerName: (json['customer_name'] as String?) ?? '',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      customerAddress: (json['customer_address'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      declineReason: json['decline_reason'] as String?,
      counterNotes: json['counter_notes'] as String?,
      counterPrice: json['counter_price'] != null ? double.tryParse(json['counter_price'].toString()) : null,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      items: rawItems.map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      latestMessage: json['latest_message'] is Map ? (json['latest_message']['message'] as String?) : null,
      latestMessageIsMe: json['latest_message'] is Map ? (json['latest_message']['is_me'] as bool? ?? false) : false,
      unreadMessageCount: (json['unread_message_count'] as int?) ?? (json['latest_message'] is Map && json['latest_message']['is_read'] == false && json['latest_message']['is_me'] == false ? 1 : 0),
      latestMessageAt: json['latest_message'] is Map && json['latest_message']['created_at'] != null ? DateTime.tryParse(json['latest_message']['created_at'].toString()) : null,
      latestMessageIsUnsent: json['latest_message'] is Map ? (json['latest_message']['is_unsent'] as bool? ?? false) : false,
    );
  }
}
