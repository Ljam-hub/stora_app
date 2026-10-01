import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stora/data/services/utang_reminder_helper.dart';
import 'package:stora/home/services/receipt_service.dart';
import 'package:stora/home/stores/utang_store.dart';
import 'package:stora/home/widgets/utang_payment_receipt_dialog.dart';

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

  group('UtangStore Anti-Double-Tap Payment Tests', () {
    test('rapid duplicate payment call within 3 seconds is ignored', () async {
      final store = UtangStore.instance;
      final initialRecord = UtangRecord(
        id: 'sample-double-tap-test',
        customerName: 'Juan Dela Cruz',
        customerPhone: '09123456789',
        totalAmount: 1000.0,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      store.setRecordsForTesting([initialRecord]);
      expect(store.records.first.balance, equals(1000.0));
      expect(store.records.first.payments.length, equals(0));

      // First payment tap
      await store.recordPayment(
        recordId: 'sample-double-tap-test',
        amount: 250.0,
        note: 'Cash payment',
      );

      expect(store.records.first.payments.length, equals(1));
      expect(store.records.first.balance, equals(750.0));

      // Second immediate tap with identical amount
      await store.recordPayment(
        recordId: 'sample-double-tap-test',
        amount: 250.0,
        note: 'Cash payment',
      );

      // Should be ignored: still 1 payment, balance still 750.0
      expect(store.records.first.payments.length, equals(1));
      expect(store.records.first.balance, equals(750.0));
    });

    test('concurrent simultaneous payments for same record are serialized/guarded', () async {
      final store = UtangStore.instance;
      final initialRecord = UtangRecord(
        id: 'sample-concurrent-test',
        customerName: 'Maria Santos',
        customerPhone: '09987654321',
        totalAmount: 500.0,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      store.setRecordsForTesting([initialRecord]);

      // Fire two payments concurrently
      await Future.wait([
        store.recordPayment(
          recordId: 'sample-concurrent-test',
          amount: 200.0,
          note: 'Concurrent 1',
        ),
        store.recordPayment(
          recordId: 'sample-concurrent-test',
          amount: 200.0,
          note: 'Concurrent 2',
        ),
      ]);

      // Mutex + rapid duplicate check ensures only 1 payment was applied
      expect(store.records.first.payments.length, equals(1));
      expect(store.records.first.balance, equals(300.0));
    });
  });

  group('UtangPaymentReceiptDialog & ReceiptService Tests', () {
    final testRecord = UtangRecord(
      id: 'rec-test-receipt',
      customerName: 'Rosalinda Cruz',
      customerPhone: '09181234567',
      totalAmount: 1000.0,
      createdAt: DateTime(2026, 9, 20),
      dueDate: DateTime(2026, 10, 10),
      payments: [
        UtangPayment(
          id: 'pay-test-1',
          amount: 300.0,
          paidAt: DateTime(2026, 9, 25, 14, 30),
          note: 'GCash',
        ),
      ],
    );

    test('generateUtangPaymentReceiptPdf generates valid PDF bytes', () async {
      final pdfBytes = await ReceiptService.instance.generateUtangPaymentReceiptPdf(
        record: testRecord,
        payment: testRecord.payments.first,
        previousBalance: 1000.0,
        businessName: 'Tindahan ni Nanay',
      );
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.take(4)), equals('%PDF'));
    });

    testWidgets('UtangPaymentReceiptDialog renders financial details and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UtangPaymentReceiptDialog(
              record: testRecord,
              payment: testRecord.payments.first,
              previousBalance: 1000.0,
            ),
          ),
        ),
      );

      expect(find.text('OFFICIAL PAYMENT RECEIPT'), findsOneWidget);
      expect(find.text('Rosalinda Cruz'), findsOneWidget);
      expect(find.text('09181234567'), findsOneWidget);
      expect(find.text('₱1000.00'), findsOneWidget); // Previous balance
      expect(find.text('₱300.00'), findsOneWidget);  // Amount paid
      expect(find.text('₱700.00'), findsOneWidget);  // Remaining balance
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.byKey(const Key('utang_receipt_done_button')), findsOneWidget);
    });
  });
}
