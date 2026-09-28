from datetime import datetime
from django.core.management.base import BaseCommand
from django.utils import timezone

from api.fcm import notify_credit_reminder
from sales.models import CustomerCredit


class Command(BaseCommand):
    help = (
        "Dispatches automated push notifications to store owners for customer loans/utang: "
        "3 days before due date, on due date, and when overdue."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Simulate and print notifications without actually dispatching FCM pushes.",
        )
        parser.add_argument(
            "--date",
            type=str,
            default=None,
            help="Simulate execution on a specific target date (format: YYYY-MM-DD).",
        )

    def handle(self, *args, **options):
        dry_run = options.get("dry_run", False)
        target_date_str = options.get("date")

        if target_date_str:
            try:
                today = datetime.strptime(target_date_str, "%Y-%m-%d").date()
            except ValueError:
                self.stderr.write(self.style.ERROR(f"Invalid date format: {target_date_str}. Use YYYY-MM-DD."))
                return
        else:
            today = timezone.localdate()

        self.stdout.write(f"Scanning customer utang records for reminders on {today} (dry_run={dry_run})...")

        active_credits = CustomerCredit.objects.filter(
            due_date__isnull=False
        ).exclude(
            status=CustomerCredit.STATUS_SETTLED
        ).select_related("owner")

        due_soon_count = 0
        due_today_count = 0
        overdue_count = 0
        dispatched_count = 0

        for credit in active_credits:
            if credit.is_fully_paid:
                continue

            diff_days = (credit.due_date - today).days

            if diff_days == 3:
                due_soon_count += 1
                self.stdout.write(
                    f" [3 Days Before] {credit.customer_name} — ₱{credit.balance} due on {credit.due_date}"
                )
                if not dry_run:
                    if notify_credit_reminder(credit, "due_soon", days_offset=3):
                        dispatched_count += 1

            elif diff_days == 0:
                due_today_count += 1
                self.stdout.write(
                    f" [Due Today] {credit.customer_name} — ₱{credit.balance} due today ({credit.due_date})"
                )
                if not dry_run:
                    if notify_credit_reminder(credit, "due_today", days_offset=0):
                        dispatched_count += 1

            elif diff_days < 0:
                overdue_count += 1
                days_overdue = abs(diff_days)
                self.stdout.write(
                    f" [Overdue] {credit.customer_name} — ₱{credit.balance} overdue by {days_overdue} days"
                )
                if not dry_run:
                    if notify_credit_reminder(credit, "overdue", days_offset=days_overdue):
                        dispatched_count += 1

        total_matching = due_soon_count + due_today_count + overdue_count
        summary_msg = (
            f"Reminders scan completed: {total_matching} qualifying utang records found "
            f"({due_soon_count} due in 3 days, {due_today_count} due today, {overdue_count} overdue). "
            f"Pushes dispatched: {dispatched_count}."
        )
        self.stdout.write(self.style.SUCCESS(summary_msg))
