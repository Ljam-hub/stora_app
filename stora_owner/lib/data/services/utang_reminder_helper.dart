import 'package:intl/intl.dart';
import '../../home/stores/utang_store.dart';

/// Representation of an utang reminder alert to be delivered to the store owner.
class UtangReminderAlert {
  final String title;
  final String body;
  final String alertType;

  const UtangReminderAlert({
    required this.title,
    required this.body,
    required this.alertType,
  });
}

/// Helper to generate human-friendly, localized reminder notifications for store owners.
class UtangReminderHelper {
  static const List<String> weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Formats currency to match standard Philippine Peso presentation (e.g. ₱350, ₱1,200, ₱1,200.50).
  static String formatBalance(double balance) {
    if (balance % 1 == 0) {
      return NumberFormat('#,##0').format(balance);
    }
    return NumberFormat('#,##0.00').format(balance);
  }

  /// Evaluates an [UtangRecord] against [currentDate] (defaulting to DateTime.now())
  /// and returns the appropriate [UtangReminderAlert], or null if no reminder is warranted.
  static UtangReminderAlert? generateAlert(UtangRecord record, [DateTime? currentDate]) {
    if (record.isFullyPaid) return null;

    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(record.dueDate.year, record.dueDate.month, record.dueDate.day);
    final diffDays = due.difference(today).inDays;
    final formattedBalance = formatBalance(record.balance);

    if (diffDays == 3) {
      // 3 Days Before Due Date (Advance Notice):
      // "Upcoming Utang: Maria Santos has a balance of ₱350 due in 3 days (Friday)."
      final weekdayName = weekdays[record.dueDate.weekday];
      return UtangReminderAlert(
        title: 'Upcoming Utang',
        body: '${record.customerName} has a balance of ₱$formattedBalance due in 3 days ($weekdayName).',
        alertType: 'due_in_3_days',
      );
    } else if (diffDays == 0) {
      // On the Due Date (Today Alert):
      // "Due Today: Juan Dela Cruz owes ₱500 due today!"
      return UtangReminderAlert(
        title: 'Due Today',
        body: '${record.customerName} owes ₱$formattedBalance due today!',
        alertType: 'due_today',
      );
    } else if (diffDays < 0) {
      // When Past Due Date (Overdue Alert):
      // "🚨 Overdue Loan: Pedro's utang of ₱1,200 is now 2 days overdue."
      final daysOverdue = diffDays.abs();
      final dayWord = daysOverdue == 1 ? 'day' : 'days';
      final penaltyNote = record.penaltyAmount > 0
          ? ' (+₱${formatBalance(record.penaltyAmount)} late fee)'
          : '';
      return UtangReminderAlert(
        title: '🚨 Overdue Loan',
        body: "${record.customerName}'s utang of ₱$formattedBalance is now $daysOverdue $dayWord overdue$penaltyNote.",
        alertType: 'overdue_$daysOverdue',
      );
    }
    return null;
  }
}
