import 'package:flutter_test/flutter_test.dart';
import 'package:stora/data/services/utang_reminder_helper.dart';
import 'package:stora/home/stores/utang_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UtangItem Model Tests', () {
    test('computes totalPrice correctly', () {
      const item = UtangItem(
        productName: 'Rice 5kg',
        quantity: 3,
        unitPrice: 250.0,
      );
      expect(item.totalPrice, equals(750.0));
    });

    test('serializes and deserializes to/from JSON', () {
      const item = UtangItem(
        productName: 'Canned Sardines',
        quantity: 4,
        unitPrice: 28.50,
      );
      final json = item.toJson();
      final fromJson = UtangItem.fromJson(json);

      expect(fromJson.productName, equals('Canned Sardines'));
      expect(fromJson.quantity, equals(4));
      expect(fromJson.unitPrice, equals(28.50));
      expect(fromJson.totalPrice, equals(114.0));
    });
  });

  group('UtangPayment Model Tests', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final payment = UtangPayment(
        id: 'pay-123',
        amount: 150.0,
        paidAt: now,
        note: 'GCash',
      );
      final json = payment.toJson();
      final fromJson = UtangPayment.fromJson(json);

      expect(fromJson.id, equals('pay-123'));
      expect(fromJson.amount, equals(150.0));
      expect(fromJson.note, equals('GCash'));
    });
  });

  group('UtangRecord Computations & Status Tests', () {
    test('computes balance and isFullyPaid correctly', () {
      final now = DateTime.now();
      final record = UtangRecord(
        id: 'test-1',
        customerName: 'Maria Santos',
        customerPhone: '09123456789',
        totalAmount: 500.0,
        createdAt: now,
        dueDate: now.add(const Duration(days: 7)),
        payments: [
          UtangPayment(id: 'p1', amount: 200.0, paidAt: now),
        ],
      );

      expect(record.amountPaid, equals(200.0));
      expect(record.balance, equals(300.0));
      expect(record.isFullyPaid, isFalse);

      final fullyPaid = record.copyWith(
        payments: [
          UtangPayment(id: 'p1', amount: 200.0, paidAt: now),
          UtangPayment(id: 'p2', amount: 300.0, paidAt: now),
        ],
      );
      expect(fullyPaid.amountPaid, equals(500.0));
      expect(fullyPaid.balance, equals(0.0));
      expect(fullyPaid.isFullyPaid, isTrue);
    });

    test('detects overdue status correctly', () {
      final now = DateTime.now();
      final overdueRecord = UtangRecord(
        id: 'test-overdue',
        customerName: 'Juan Dela Cruz',
        customerPhone: '09987654321',
        totalAmount: 1000.0,
        createdAt: now.subtract(const Duration(days: 14)),
        dueDate: now.subtract(const Duration(days: 2)),
      );

      expect(overdueRecord.isOverdue, isTrue);
      expect(overdueRecord.isDueToday, isFalse);
      expect(overdueRecord.isDueSoon, isFalse);
    });

    test('detects due today status correctly', () {
      final now = DateTime.now();
      final dueTodayRecord = UtangRecord(
        id: 'test-today',
        customerName: 'Aling Nena',
        customerPhone: '09111111111',
        totalAmount: 250.0,
        createdAt: now.subtract(const Duration(days: 5)),
        dueDate: DateTime(now.year, now.month, now.day),
      );

      expect(dueTodayRecord.isDueToday, isTrue);
      expect(dueTodayRecord.isOverdue, isFalse);
      expect(dueTodayRecord.isDueSoon, isFalse);
    });

    test('detects due soon (within 3 days) correctly', () {
      final now = DateTime.now();
      final dueSoonRecord = UtangRecord(
        id: 'test-soon',
        customerName: 'Pedro Penduko',
        customerPhone: '',
        totalAmount: 120.0,
        createdAt: now,
        dueDate: now.add(const Duration(days: 2)),
      );

      expect(dueSoonRecord.isDueSoon, isTrue);
      expect(dueSoonRecord.isDueToday, isFalse);
      expect(dueSoonRecord.isOverdue, isFalse);
    });

    test('serializes and deserializes full UtangRecord with items and payments', () {
      final now = DateTime.now();
      final record = UtangRecord(
        id: 'test-full',
        customerName: 'Aling Marites',
        customerPhone: '09191234567',
        totalAmount: 350.0,
        createdAt: now,
        dueDate: now.add(const Duration(days: 5)),
        items: const [
          UtangItem(productName: 'Cooking Oil', quantity: 2, unitPrice: 50.0),
          UtangItem(productName: 'Sugar 1kg', quantity: 3, unitPrice: 83.33),
        ],
        payments: [
          UtangPayment(id: 'pay-1', amount: 100.0, paidAt: now, note: 'Downpayment'),
        ],
        notes: 'Suki discount applied',
      );

      final json = record.toJson();
      final fromJson = UtangRecord.fromJson(json);

      expect(fromJson.id, equals('test-full'));
      expect(fromJson.customerName, equals('Aling Marites'));
      expect(fromJson.customerPhone, equals('09191234567'));
      expect(fromJson.totalAmount, equals(350.0));
      expect(fromJson.items.length, equals(2));
      expect(fromJson.payments.length, equals(1));
      expect(fromJson.amountPaid, equals(100.0));
      expect(fromJson.balance, equals(250.0));
      expect(fromJson.notes, equals('Suki discount applied'));
    });
  });

  group('UtangReminderHelper Notification Generator Tests', () {
    test('generates advance notice 3 days before due date', () {
      // Reference date: Tuesday, 2026-09-22
      final currentDate = DateTime(2026, 9, 22);
      // Due date: Friday, 2026-09-25 (exactly 3 days ahead)
      final dueDate = DateTime(2026, 9, 25);

      final record = UtangRecord(
        id: 'rec-maria',
        customerName: 'Maria Santos',
        customerPhone: '09123456789',
        totalAmount: 350.0,
        createdAt: DateTime(2026, 9, 18),
        dueDate: dueDate,
      );

      final alert = UtangReminderHelper.generateAlert(record, currentDate);
      expect(alert, isNotNull);
      expect(alert!.title, equals('Upcoming Utang'));
      expect(alert.body, equals('Maria Santos has a balance of ₱350 due in 3 days (Friday).'));
      expect(alert.alertType, equals('due_in_3_days'));
    });

    test('generates today alert on the due date', () {
      final currentDate = DateTime(2026, 9, 28);
      final dueDate = DateTime(2026, 9, 28);

      final record = UtangRecord(
        id: 'rec-juan',
        customerName: 'Juan Dela Cruz',
        customerPhone: '09987654321',
        totalAmount: 500.0,
        createdAt: DateTime(2026, 9, 20),
        dueDate: dueDate,
      );

      final alert = UtangReminderHelper.generateAlert(record, currentDate);
      expect(alert, isNotNull);
      expect(alert!.title, equals('Due Today'));
      expect(alert.body, equals('Juan Dela Cruz owes ₱500 due today!'));
      expect(alert.alertType, equals('due_today'));
    });

    test('generates overdue alert when past due date by 2 days', () {
      final currentDate = DateTime(2026, 9, 30);
      // Due date: 2026-09-28 (2 days overdue)
      final dueDate = DateTime(2026, 9, 28);

      final record = UtangRecord(
        id: 'rec-pedro',
        customerName: 'Pedro',
        customerPhone: '09112223333',
        totalAmount: 1200.0,
        createdAt: DateTime(2026, 9, 15),
        dueDate: dueDate,
      );

      final alert = UtangReminderHelper.generateAlert(record, currentDate);
      expect(alert, isNotNull);
      expect(alert!.title, equals('🚨 Overdue Loan'));
      expect(alert.body, equals("Pedro's utang of ₱1,200 is now 2 days overdue."));
      expect(alert.alertType, equals('overdue_2'));
    });

    test('generates overdue alert with singular day when 1 day overdue', () {
      final currentDate = DateTime(2026, 9, 29);
      final dueDate = DateTime(2026, 9, 28);

      final record = UtangRecord(
        id: 'rec-pedro-1',
        customerName: 'Pedro',
        customerPhone: '09112223333',
        totalAmount: 1200.0,
        createdAt: DateTime(2026, 9, 15),
        dueDate: dueDate,
      );

      final alert = UtangReminderHelper.generateAlert(record, currentDate);
      expect(alert, isNotNull);
      expect(alert!.title, equals('🚨 Overdue Loan'));
      expect(alert.body, equals("Pedro's utang of ₱1,200 is now 1 day overdue."));
      expect(alert.alertType, equals('overdue_1'));
    });

    test('returns null when record is fully paid', () {
      final currentDate = DateTime(2026, 9, 28);
      final record = UtangRecord(
        id: 'rec-paid',
        customerName: 'Maria Santos',
        customerPhone: '09123456789',
        totalAmount: 350.0,
        createdAt: DateTime(2026, 9, 18),
        dueDate: currentDate,
        payments: [
          UtangPayment(id: 'p1', amount: 350.0, paidAt: currentDate),
        ],
      );

      final alert = UtangReminderHelper.generateAlert(record, currentDate);
      expect(alert, isNull);
    });
  });
}
