import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/api/api_client.dart';
import '../../data/services/notification_service.dart';

class UtangItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  const UtangItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory UtangItem.fromJson(Map<String, dynamic> json) => UtangItem(
        productName: json['product_name'] as String? ?? 'Item',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ??
            (double.tryParse(json['unit_price']?.toString() ?? '') ?? 0.0),
      );
}

class UtangPayment {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String? note;

  const UtangPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        'note': note,
      };

  factory UtangPayment.fromJson(Map<String, dynamic> json) => UtangPayment(
        id: json['id']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ??
            (double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? '') ?? DateTime.now(),
        note: json['notes'] as String? ?? json['note'] as String?,
      );
}

class UtangRecord {
  final String id;
  final String customerName;
  final String customerPhone;
  final double totalAmount;
  final List<UtangPayment> payments;
  final DateTime createdAt;
  final DateTime dueDate;
  final List<UtangItem> items;
  final String notes;

  UtangRecord({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    this.payments = const [],
    required this.createdAt,
    required this.dueDate,
    this.items = const [],
    this.notes = '',
  });

  double get amountPaid => payments.fold(0.0, (sum, p) => sum + p.amount);
  double get balance => (totalAmount - amountPaid).clamp(0.0, double.infinity);
  bool get isFullyPaid => balance <= 0.01;

  bool get isOverdue {
    if (isFullyPaid) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(due);
  }

  bool get isDueToday {
    if (isFullyPaid) return false;
    final now = DateTime.now();
    return now.year == dueDate.year && now.month == dueDate.month && now.day == dueDate.day;
  }

  bool get isDueSoon {
    if (isFullyPaid || isOverdue || isDueToday) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;
    return diff > 0 && diff <= 3;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'total_amount': totalAmount,
        'payments': payments.map((p) => p.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
      };

  factory UtangRecord.fromJson(Map<String, dynamic> json) => UtangRecord(
        id: json['id']?.toString() ?? '',
        customerName: json['customer_name'] as String? ?? 'Walk-in Customer',
        customerPhone: json['customer_phone'] as String? ?? '',
        totalAmount: (json['total_amount'] as num?)?.toDouble() ??
            (double.tryParse(json['total_amount']?.toString() ?? '') ?? 0.0),
        payments: (json['payments'] as List<dynamic>?)
                ?.map((p) => UtangPayment.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 7)),
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => UtangItem.fromJson(Map<String, dynamic>.from(i as Map)))
                .toList() ??
            [],
        notes: json['notes'] as String? ?? '',
      );

  UtangRecord copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    double? totalAmount,
    List<UtangPayment>? payments,
    DateTime? dueDate,
    List<UtangItem>? items,
    String? notes,
  }) {
    return UtangRecord(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      payments: payments ?? this.payments,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      notes: notes ?? this.notes,
    );
  }
}

class UtangStore extends ChangeNotifier {
  UtangStore._internal() {
    load();
  }
  static final UtangStore instance = UtangStore._internal();

  List<UtangRecord> _records = [];
  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  List<UtangRecord> get records => List.unmodifiable(_records);

  List<UtangRecord> get activeRecords => _records.where((r) => !r.isFullyPaid).toList();

  List<UtangRecord> get overdueRecords => _records.where((r) => r.isOverdue).toList();

  List<UtangRecord> get dueTodayOrSoonRecords =>
      _records.where((r) => r.isDueToday || r.isDueSoon).toList();

  List<UtangRecord> get paidRecords => _records.where((r) => r.isFullyPaid).toList();

  double get totalOutstanding => activeRecords.fold(0.0, (sum, r) => sum + r.balance);

  int get totalActiveDebtors =>
      activeRecords.map((r) => r.customerName.toLowerCase().trim()).toSet().length;

  List<String> get uniqueCustomerNames =>
      _records.map((r) => r.customerName.trim()).where((n) => n.isNotEmpty).toSet().toList();

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/stora_utang_records.json');
  }

  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          _records = list
              .map((e) => UtangRecord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      }
    } catch (e) {
      debugPrint('UtangStore load error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
      OwnerNotificationService.instance.checkAndNotifyUtang(_records);
      syncWithBackend();
    }
  }

  Future<void> syncWithBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // 1. Replay any pending offline payments on existing server records
      for (final localRec in _records) {
        if (!localRec.id.startsWith('utang-') && !localRec.id.startsWith('sample-')) {
          final unsyncedPayments = localRec.payments.where((p) => p.id.startsWith('pay-')).toList();
          for (final p in unsyncedPayments) {
            try {
              await ApiClient.instance.addCreditPayment(localRec.id, {
                'amount': p.amount,
                'notes': p.note ?? '',
              });
            } catch (_) {}
          }
        }
      }

      // 2. Replay any pending offline created records
      final pendingOffline = _records.where((r) => r.id.startsWith('utang-')).toList();
      for (final pending in pendingOffline) {
        try {
          final payload = {
            'customer_name': pending.customerName,
            'customer_phone': pending.customerPhone,
            'total_amount': pending.totalAmount,
            'due_date': pending.dueDate.toIso8601String().split('T')[0],
            'notes': pending.notes,
            'items': pending.items.map((i) => i.toJson()).toList(),
          };
          final serverResp = await ApiClient.instance.createCredit(payload);
          if (serverResp.containsKey('id')) {
            final serverId = serverResp['id'].toString();
            // Replay any offline payments that were logged on this pending record
            for (final p in pending.payments) {
              try {
                await ApiClient.instance.addCreditPayment(serverId, {
                  'amount': p.amount,
                  'notes': p.note ?? '',
                });
              } catch (_) {}
            }
            _records.removeWhere((r) => r.id == pending.id);
          }
        } catch (e) {
          debugPrint('UtangStore push pending record error: $e');
        }
      }

      // 3. Fetch canonical state from cloud backend
      final remoteList = await ApiClient.instance.listCredits();
      final remoteRecords = remoteList.map((json) {
        return UtangRecord.fromJson({
          ...json,
          'id': json['id']?.toString() ?? '',
        });
      }).toList();

      // Keep any still-pending offline records
      final remainingPending = _records.where((r) => r.id.startsWith('utang-')).toList();
      _records = [...remoteRecords, ...remainingPending];
      _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _save();
    } catch (e) {
      debugPrint('UtangStore syncWithBackend: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
      OwnerNotificationService.instance.checkAndNotifyUtang(_records);
    }
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = _records.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('UtangStore save error: $e');
    }
  }

  Future<UtangRecord> addUtang({
    required String customerName,
    required String customerPhone,
    required double totalAmount,
    required DateTime dueDate,
    List<UtangItem> items = const [],
    String notes = '',
  }) async {
    final tempId = 'utang-${DateTime.now().millisecondsSinceEpoch}';
    var record = UtangRecord(
      id: tempId,
      customerName: customerName.trim().isEmpty ? 'Walk-in Customer' : customerName.trim(),
      customerPhone: customerPhone.trim(),
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      items: items,
      notes: notes.trim(),
    );

    _records.insert(0, record);
    notifyListeners();
    await _save();
    OwnerNotificationService.instance.checkAndNotifyUtang(_records);

    // Background sync to backend
    try {
      final payload = {
        'customer_name': record.customerName,
        'customer_phone': record.customerPhone,
        'total_amount': record.totalAmount,
        'due_date': record.dueDate.toIso8601String().split('T')[0],
        'notes': record.notes,
        'items': items.map((i) => i.toJson()).toList(),
      };
      final serverResp = await ApiClient.instance.createCredit(payload);
      if (serverResp.containsKey('id')) {
        final serverId = serverResp['id'].toString();
        final idx = _records.indexWhere((r) => r.id == tempId);
        if (idx != -1) {
          record = _records[idx].copyWith(id: serverId);
          _records[idx] = record;
          await _save();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('UtangStore cloud create error: $e');
    }

    return record;
  }

  Future<void> recordPayment({
    required String recordId,
    required double amount,
    String? note,
  }) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    final existing = _records[index];
    final payment = UtangPayment(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      paidAt: DateTime.now(),
      note: note,
    );

    final updatedPayments = List<UtangPayment>.from(existing.payments)..add(payment);
    _records[index] = existing.copyWith(payments: updatedPayments);
    notifyListeners();
    await _save();

    if (!recordId.startsWith('utang-') && !recordId.startsWith('sample-')) {
      try {
        await ApiClient.instance.addCreditPayment(recordId, {
          'amount': amount,
          'notes': note ?? '',
        });
      } catch (e) {
        debugPrint('UtangStore cloud payment error: $e');
      }
    }
  }

  Future<void> updateDueDate(String recordId, DateTime newDueDate) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    _records[index] = _records[index].copyWith(dueDate: newDueDate);
    notifyListeners();
    await _save();

    if (!recordId.startsWith('utang-') && !recordId.startsWith('sample-')) {
      try {
        await ApiClient.instance.updateCredit(recordId, {
          'due_date': newDueDate.toIso8601String().split('T')[0],
        });
      } catch (e) {
        debugPrint('UtangStore cloud updateDueDate error: $e');
      }
    }
  }

  Future<void> deleteUtang(String recordId) async {
    _records.removeWhere((r) => r.id == recordId);
    notifyListeners();
    await _save();

    if (!recordId.startsWith('utang-') && !recordId.startsWith('sample-')) {
      try {
        await ApiClient.instance.deleteCredit(recordId);
      } catch (e) {
        debugPrint('UtangStore cloud delete error: $e');
      }
    }
  }

  Future<int> checkReminders([DateTime? currentDate]) async {
    return OwnerNotificationService.instance.checkAndNotifyUtang(_records, currentDate);
  }

  void reset() {
    _records.clear();
    _initialized = false;
    notifyListeners();
  }
}
