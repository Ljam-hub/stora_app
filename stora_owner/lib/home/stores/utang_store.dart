import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/api/api_client.dart';
import '../../data/services/notification_service.dart';

/// Safely parses a JSON value that may be a [num] or a [String] (e.g. DRF
/// DecimalField serializes decimals as strings like "350.00").
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

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
        unitPrice: _parseDouble(json['unit_price']),
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
        amount: _parseDouble(json['amount']),
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
  final double penaltyRate;
  /// Frequency of the penalty: 'none', 'daily', 'weekly', 'monthly'.
  final String penaltyFrequency;
  final int gracePeriodDays;
  final bool isPenaltyWaived;
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
    double penaltyRate = 0.0,
    String penaltyFrequency = 'none',
    double? dailyPenalty,
    this.gracePeriodDays = 0,
    this.isPenaltyWaived = false,
    this.items = const [],
    this.notes = '',
  })  : penaltyRate = (dailyPenalty != null && dailyPenalty > 0 && penaltyRate == 0.0)
            ? dailyPenalty
            : penaltyRate,
        penaltyFrequency = (dailyPenalty != null && dailyPenalty > 0 && penaltyFrequency == 'none')
            ? 'daily'
            : penaltyFrequency;

  /// Backwards-compatibility getter for daily late fee
  double get dailyPenalty => penaltyFrequency == 'daily' ? penaltyRate : 0.0;
  bool get hasPenalty => penaltyFrequency != 'none' && penaltyRate > 0;

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

  int get overdueDays {
    if (isFullyPaid) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (!today.isAfter(due)) return 0;
    return today.difference(due).inDays;
  }

  int get billableOverdueDays {
    final days = overdueDays;
    if (days <= gracePeriodDays) return 0;
    return days - gracePeriodDays;
  }

  /// Calculates how many penalty billing units have elapsed (e.g. days, weeks, months)
  int get overdueUnits {
    if (isPenaltyWaived || penaltyRate <= 0 || !isOverdue || penaltyFrequency == 'none') return 0;
    final billable = billableOverdueDays;
    if (billable <= 0) return 0;
    switch (penaltyFrequency) {
      case 'daily':
        return billable;
      case 'weekly':
        return ((billable - 1) ~/ 7) + 1;
      case 'monthly':
        return ((billable - 1) ~/ 30) + 1;
      default:
        return 0;
    }
  }

  String get penaltyFrequencyLabel {
    switch (penaltyFrequency) {
      case 'daily':
        return 'Per Day';
      case 'weekly':
        return 'Per Week';
      case 'monthly':
        return 'Per Month';
      default:
        return 'None';
    }
  }

  String get penaltyFrequencyShortUnit {
    switch (penaltyFrequency) {
      case 'daily':
        return 'day';
      case 'weekly':
        return 'wk';
      case 'monthly':
        return 'mo';
      default:
        return '';
    }
  }

  String get penaltyFrequencyTagalog {
    switch (penaltyFrequency) {
      case 'daily':
        return 'araw';
      case 'weekly':
        return 'linggo';
      case 'monthly':
        return 'buwan';
      default:
        return '';
    }
  }

  String get overdueUnitsLabel {
    final units = overdueUnits;
    if (units <= 0) return '';
    switch (penaltyFrequency) {
      case 'daily':
        return '$units ${units == 1 ? 'day' : 'days'}';
      case 'weekly':
        return '$units ${units == 1 ? 'week' : 'weeks'}';
      case 'monthly':
        return '$units ${units == 1 ? 'month' : 'months'}';
      default:
        return '';
    }
  }

  String get overdueUnitsTagalog {
    final units = overdueUnits;
    if (units <= 0) return '';
    switch (penaltyFrequency) {
      case 'daily':
        return '$units araw';
      case 'weekly':
        return '$units linggo';
      case 'monthly':
        return '$units buwan';
      default:
        return '';
    }
  }

  double get penaltyAmount {
    if (isPenaltyWaived || penaltyRate <= 0 || !isOverdue || penaltyFrequency == 'none') return 0.0;
    final units = overdueUnits;
    if (units <= 0) return 0.0;
    final raw = units * penaltyRate;
    // Cap safeguard: penalty cannot exceed remaining balance
    return raw > balance ? balance : raw;
  }

  double get totalDueWithPenalty => balance + penaltyAmount;

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
        'penalty_rate': penaltyRate,
        'penalty_frequency': penaltyFrequency,
        'daily_penalty': dailyPenalty,
        'grace_period_days': gracePeriodDays,
        'is_penalty_waived': isPenaltyWaived,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
      };

  factory UtangRecord.fromJson(Map<String, dynamic> json) {
    final legacyDaily = _parseDouble(json['daily_penalty']);
    final savedRate = _parseDouble(json['penalty_rate']);
    final rate = savedRate > 0 ? savedRate : legacyDaily;
    String freq = (json['penalty_frequency'] as String? ?? '').trim().toLowerCase();
    if (freq.isEmpty) {
      freq = rate > 0 ? 'daily' : 'none';
    }

    return UtangRecord(
      id: json['id']?.toString() ?? '',
      customerName: json['customer_name'] as String? ?? 'Walk-in Customer',
      customerPhone: json['customer_phone'] as String? ?? '',
      totalAmount: _parseDouble(json['total_amount']),
      payments: (json['payments'] as List<dynamic>?)
              ?.map((p) => UtangPayment.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      penaltyRate: rate,
      penaltyFrequency: freq,
      gracePeriodDays: (json['grace_period_days'] as num?)?.toInt() ?? 0,
      isPenaltyWaived: json['is_penalty_waived'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => UtangItem.fromJson(Map<String, dynamic>.from(i as Map)))
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
    );
  }

  UtangRecord copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    double? totalAmount,
    List<UtangPayment>? payments,
    DateTime? dueDate,
    double? penaltyRate,
    String? penaltyFrequency,
    double? dailyPenalty,
    int? gracePeriodDays,
    bool? isPenaltyWaived,
    List<UtangItem>? items,
    String? notes,
  }) {
    final resolvedRate = penaltyRate ?? dailyPenalty ?? this.penaltyRate;
    final resolvedFreq = penaltyFrequency ??
        (dailyPenalty != null && dailyPenalty > 0 && penaltyRate == null
            ? 'daily'
            : this.penaltyFrequency);

    return UtangRecord(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      payments: payments ?? this.payments,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      penaltyRate: resolvedRate,
      penaltyFrequency: resolvedFreq,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      isPenaltyWaived: isPenaltyWaived ?? this.isPenaltyWaived,
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

  double get totalOutstanding => activeRecords.fold(0.0, (sum, r) => sum + r.totalDueWithPenalty);

  double get totalPrincipalOutstanding => activeRecords.fold(0.0, (sum, r) => sum + r.balance);

  double get totalAccruedPenalties => activeRecords.fold(0.0, (sum, r) => sum + r.penaltyAmount);

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

      // 3. Fetch canonical state from cloud backend, preserving local penalty configs
      final remoteList = await ApiClient.instance.listCredits();
      final existingMap = {for (final r in _records) r.id: r};
      final remoteRecords = remoteList.map((json) {
        final id = json['id']?.toString() ?? '';
        final local = existingMap[id];
        final rec = UtangRecord.fromJson({
          ...json,
          'id': id,
        });
        if (local != null) {
          return rec.copyWith(
            penaltyRate: local.penaltyRate,
            penaltyFrequency: local.penaltyFrequency,
            gracePeriodDays: local.gracePeriodDays,
            isPenaltyWaived: local.isPenaltyWaived,
          );
        }
        return rec;
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
    double penaltyRate = 0.0,
    String penaltyFrequency = 'none',
    double? dailyPenalty,
    int gracePeriodDays = 0,
    List<UtangItem> items = const [],
    String notes = '',
  }) async {
    final tempId = 'utang-${DateTime.now().millisecondsSinceEpoch}';
    final resolvedRate = (dailyPenalty != null && dailyPenalty > 0 && penaltyRate == 0.0)
        ? dailyPenalty
        : penaltyRate;
    final resolvedFreq = (dailyPenalty != null && dailyPenalty > 0 && penaltyFrequency == 'none')
        ? 'daily'
        : penaltyFrequency;

    var record = UtangRecord(
      id: tempId,
      customerName: customerName.trim().isEmpty ? 'Walk-in Customer' : customerName.trim(),
      customerPhone: customerPhone.trim(),
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      penaltyRate: resolvedRate,
      penaltyFrequency: resolvedFreq,
      gracePeriodDays: gracePeriodDays,
      isPenaltyWaived: false,
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

    double updatedTotalAmount = existing.totalAmount;
    List<UtangItem> updatedItems = existing.items;
    if (amount > existing.balance && existing.penaltyAmount > 0) {
      final penaltyPaid = (amount - existing.balance).clamp(0.0, existing.penaltyAmount);
      updatedTotalAmount += penaltyPaid;
      updatedItems = [
        ...existing.items,
        UtangItem(
          productName: 'Late Payment Penalty Fee',
          quantity: 1,
          unitPrice: penaltyPaid,
        ),
      ];
    }

    final updatedPayments = List<UtangPayment>.from(existing.payments)..add(payment);
    _records[index] = existing.copyWith(
      totalAmount: updatedTotalAmount,
      items: updatedItems,
      payments: updatedPayments,
    );
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

  Future<void> waivePenalty(String recordId, {bool waived = true}) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    _records[index] = _records[index].copyWith(isPenaltyWaived: waived);
    notifyListeners();
    await _save();
  }

  Future<void> updatePenaltySettings(
    String recordId, {
    double penaltyRate = 0.0,
    String penaltyFrequency = 'none',
    required int gracePeriodDays,
    double? dailyPenalty,
  }) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    final resolvedRate = (dailyPenalty != null && dailyPenalty > 0 && penaltyRate == 0.0)
        ? dailyPenalty
        : penaltyRate;
    final resolvedFreq = (dailyPenalty != null && dailyPenalty > 0 && penaltyFrequency == 'none')
        ? 'daily'
        : penaltyFrequency;

    _records[index] = _records[index].copyWith(
      penaltyRate: resolvedRate,
      penaltyFrequency: resolvedFreq,
      gracePeriodDays: gracePeriodDays,
    );
    notifyListeners();
    await _save();
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
