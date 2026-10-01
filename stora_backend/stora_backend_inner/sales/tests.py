from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from inventory.models import Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale, SaleItem

User = get_user_model()


class SaleAndReceiptTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username="owner@test.com",
            email="owner@test.com",
            password="password123",
            business_name="Super Mart",
            role="owner",
        )
        self.customer = User.objects.create_user(
            username="customer@test.com",
            email="customer@test.com",
            first_name="Maria",
            last_name="Clara",
            role="customer",
        )
        self.category = Category.objects.create(name="Snacks", owner=self.owner)
        self.product = Product.objects.create(
            owner=self.owner,
            category=self.category,
            name="Chips",
            price=Decimal("50.00"),
            stock=20,
        )

    def test_pos_sale_creation_default_customer_name(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "items": [
                {"product": self.product.id, "quantity": 2},
            ],
        }
        response = self.client.post("/api/sales/", data=payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["customer_name"], "Walk-in Customer")
        self.assertTrue(response.data["receipt_number"].startswith("POS-"))
        self.assertEqual(response.data["channel"], "in_store")
        self.assertIsNone(response.data["order_id"])

    def test_pos_sale_creation_custom_customer_name(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "customer_name": "Juan Dela Cruz",
            "items": [
                {"product": self.product.id, "quantity": 1},
            ],
        }
        response = self.client.post("/api/sales/", data=payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["customer_name"], "Juan Dela Cruz")
        self.assertTrue(response.data["receipt_number"].startswith("POS-"))
        self.assertEqual(response.data["channel"], "in_store")

    def test_order_acceptance_receipt_matches_order(self):
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Maria Clara",
            customer_phone="09181234567",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=2,
            unit_price=Decimal("50.00"),
        )

        self.client.force_authenticate(user=self.owner)
        accept_resp = self.client.post(f"/api/orders/{order.id}/accept/")
        self.assertEqual(accept_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(accept_resp.data["receipt_number"], f"ORD-{order.id}")

        # Check sale created
        sale = Sale.objects.get(order=order)
        self.assertEqual(sale.receipt_number, f"ORD-{order.id}")
        self.assertEqual(sale.customer_name, "Maria Clara")
        self.assertEqual(sale.channel, "online_order")
        self.assertEqual(sale.order_id, order.id)

        # Check GET /api/sales/
        sales_resp = self.client.get("/api/sales/")
        self.assertEqual(sales_resp.status_code, status.HTTP_200_OK)
        matching_sale = next(s for s in sales_resp.data if s["id"] == sale.id)
        self.assertEqual(matching_sale["receipt_number"], f"ORD-{order.id}")
        self.assertEqual(matching_sale["customer_name"], "Maria Clara")
        self.assertEqual(matching_sale["order_id"], order.id)
        self.assertEqual(matching_sale["channel"], "online_order")

        # Check GET /api/orders/ for customer
        self.client.force_authenticate(user=self.customer)
        orders_resp = self.client.get("/api/orders/")
        self.assertEqual(orders_resp.status_code, status.HTTP_200_OK)
        matching_order = next(o for o in orders_resp.data if o["id"] == order.id)
        self.assertEqual(matching_order["receipt_number"], f"ORD-{order.id}")
        self.assertEqual(matching_order["customer_name"], "Maria Clara")

    def test_sale_model_auto_receipt_number(self):
        # Direct creation without receipt_number
        sale = Sale.objects.create(
            owner=self.owner,
            total=Decimal("100.00"),
        )
        sale.refresh_from_db()
        self.assertEqual(sale.receipt_number, f"POS-{sale.id}")
        self.assertEqual(sale.customer_name, "Walk-in Customer")

    def test_recalculate_total_preserves_counter_price(self):
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            counter_price=Decimal("180.00"),
            status=Order.STATUS_ACCEPTED,
        )
        sale = Sale.objects.create(
            owner=self.owner,
            order=order,
            total=Decimal("180.00"),
            receipt_number=f"ORD-{order.id}",
        )
        SaleItem.objects.create(
            sale=sale,
            product=self.product,
            product_name=self.product.name,
            quantity=4,
            unit_price=Decimal("50.00"),  # 4 * 50 = 200.00
        )
        sale.recalculate_total()
        self.assertEqual(sale.total, Decimal("180.00"))

    def test_sale_admin_changelist_rendering(self):
        admin_user = User.objects.create_superuser(
            username="admin@test.com",
            email="admin@test.com",
            password="adminpassword123",
            role="admin",
        )
        # Create a POS sale with items
        pos_sale = Sale.objects.create(
            owner=self.owner,
            total=Decimal("150.75"),
            customer_name="Walk-in Customer",
        )
        SaleItem.objects.create(
            sale=pos_sale,
            product=self.product,
            product_name=self.product.name,
            quantity=3,
            unit_price=Decimal("50.25"),
        )
        # Create an online order sale with items
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Maria Clara",
            status=Order.STATUS_ACCEPTED,
        )
        order_sale = Sale.objects.create(
            owner=self.owner,
            order=order,
            total=Decimal("99.99"),
            channel="online_order",
            customer_name="Maria Clara",
        )
        SaleItem.objects.create(
            sale=order_sale,
            product=self.product,
            product_name="Special Item {Test}",
            quantity=1,
            unit_price=Decimal("99.99"),
        )

        self.client.force_login(admin_user)
        response = self.client.get("/admin/sales/sale/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Verify rendered content
        content = response.content.decode("utf-8")
        self.assertIn("Walk-in Customer", content)
        self.assertIn("Maria Clara", content)
        self.assertIn("ORD #", content)
        self.assertIn("Special Item {Test}", content)

    def test_sale_admin_changeform_no_phantom_original_text(self):
        admin_user = User.objects.create_superuser(
            username="admin2@test.com",
            email="admin2@test.com",
            password="adminpassword123",
            role="admin",
        )
        sale = Sale.objects.create(
            owner=self.owner,
            total=Decimal("150.00"),
            customer_name="Walk-in Customer",
        )
        SaleItem.objects.create(
            sale=sale,
            product=self.product,
            product_name="Sample Beverage",
            quantity=2,
            unit_price=Decimal("75.00"),
        )
        self.client.force_login(admin_user)
        response = self.client.get(f"/admin/sales/sale/{sale.id}/change/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        content = response.content.decode("utf-8")
        # Ensure the change form loads properly
        self.assertIn("Sample Beverage", content)
        # Ensure <td class="original"> does NOT output the phantom <p> text
        self.assertNotIn('<td class="original">\n          <p>', content)
        self.assertNotIn('<td class="original"><p>', content)


class CustomerCreditTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username="owner_credit@test.com",
            email="owner_credit@test.com",
            password="password123",
            business_name="Credit Store",
            role="owner",
        )
        self.customer = User.objects.create_user(
            username="customer_credit@test.com",
            email="customer_credit@test.com",
            password="password123",
            role="customer",
        )
        self.category = Category.objects.create(name="Groceries", owner=self.owner)
        self.product = Product.objects.create(
            owner=self.owner,
            category=self.category,
            name="Canned Meat",
            price=Decimal("45.00"),
            stock=50,
        )

    def test_create_customer_credit_api(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "customer_name": "Aling Nena",
            "customer_phone": "09171112233",
            "total_amount": "90.00",
            "due_date": "2026-10-15",
            "notes": "Pang-almusal",
            "items": [
                {
                    "product": self.product.id,
                    "product_name": self.product.name,
                    "quantity": 2,
                    "unit_price": "45.00",
                }
            ],
        }
        response = self.client.post("/api/credits/", data=payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["customer_name"], "Aling Nena")
        self.assertEqual(response.data["total_amount"], "90.00")
        self.assertEqual(response.data["balance"], "90.00")
        self.assertFalse(response.data["is_fully_paid"])

        # Check list endpoint
        list_resp = self.client.get("/api/credits/")
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_resp.data), 1)

    def test_add_payment_and_settle(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "customer_name": "Juan Listahan",
            "total_amount": "100.00",
            "due_date": "2026-10-10",
        }
        create_resp = self.client.post("/api/credits/", data=payload, format="json")
        credit_id = create_resp.data["id"]

        # Partial payment
        pay_resp = self.client.post(
            f"/api/credits/{credit_id}/add_payment/",
            data={"amount": "40.00", "notes": "First partial"},
            format="json",
        )
        self.assertEqual(pay_resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(pay_resp.data["amount_paid"], "40.00")
        self.assertEqual(pay_resp.data["balance"], "60.00")
        self.assertFalse(pay_resp.data["is_fully_paid"])

        # Remaining payment to settle
        pay_resp2 = self.client.post(
            f"/api/credits/{credit_id}/add_payment/",
            data={"amount": "60.00", "notes": "Fully paid"},
            format="json",
        )
        self.assertEqual(pay_resp2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(pay_resp2.data["balance"], "0.00")
        self.assertTrue(pay_resp2.data["is_fully_paid"])
        self.assertEqual(pay_resp2.data["status"], "settled")

    def test_rapid_double_tap_payment_idempotent(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "customer_name": "Rapid Tap Customer",
            "total_amount": "100.00",
            "due_date": "2026-10-10",
        }
        create_resp = self.client.post("/api/credits/", data=payload, format="json")
        credit_id = create_resp.data["id"]

        # First tap
        pay_resp1 = self.client.post(
            f"/api/credits/{credit_id}/add_payment/",
            data={"amount": "30.00", "notes": "First tap"},
            format="json",
        )
        self.assertEqual(pay_resp1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(pay_resp1.data["amount_paid"], "30.00")
        self.assertEqual(pay_resp1.data["balance"], "70.00")

        # Second tap immediately (within 4 seconds)
        pay_resp2 = self.client.post(
            f"/api/credits/{credit_id}/add_payment/",
            data={"amount": "30.00", "notes": "First tap"},
            format="json",
        )
        # Should be handled gracefully with 200 OK without double-charging
        self.assertEqual(pay_resp2.status_code, status.HTTP_200_OK)
        self.assertEqual(pay_resp2.data["amount_paid"], "30.00")
        self.assertEqual(pay_resp2.data["balance"], "70.00")

        # Ensure database has exactly 1 payment record, not 2
        from sales.models import CustomerCredit
        credit = CustomerCredit.objects.get(id=credit_id)
        self.assertEqual(credit.payments.count(), 1)
        self.assertEqual(credit.amount_paid, Decimal("30.00"))

    def test_credit_admin_changelist_and_dashboard(self):
        admin_user = User.objects.create_superuser(
            username="admin_credit@test.com",
            email="admin_credit@test.com",
            password="adminpassword123",
            role="admin",
        )
        # Create credit records
        from sales.models import CustomerCredit
        CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Pedro Overdue",
            total_amount=Decimal("200.00"),
            due_date="2026-01-01", # Overdue
            status=CustomerCredit.STATUS_OVERDUE,
        )

        self.client.force_login(admin_user)
        # Admin changelist
        changelist_resp = self.client.get("/admin/sales/customercredit/")
        self.assertEqual(changelist_resp.status_code, status.HTTP_200_OK)
        content = changelist_resp.content.decode("utf-8")
        self.assertIn("Pedro Overdue", content)
        self.assertIn("OVERDUE", content)

        # Admin dashboard
        index_resp = self.client.get("/admin/")
        self.assertEqual(index_resp.status_code, status.HTTP_200_OK)
        index_content = index_resp.content.decode("utf-8")
        self.assertIn("Store Credit / Utang", index_content)
        self.assertIn("Overdue Customer Loans", index_content)

    def test_credit_patch_and_filtering(self):
        self.client.force_authenticate(user=self.owner)
        payload = {
            "customer_name": "Juan Dela Cruz",
            "customer_phone": "09123456789",
            "total_amount": "500.00",
            "due_date": "2026-10-15",
            "notes": "Initial note",
        }
        res = self.client.post("/api/credits/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        credit_id = res.data["id"]

        # PATCH update due_date and notes
        patch_res = self.client.patch(
            f"/api/credits/{credit_id}/",
            data={"due_date": "2026-11-01", "notes": "Extended due date"},
            format="json",
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_res.data["due_date"], "2026-11-01")
        self.assertEqual(patch_res.data["notes"], "Extended due date")

        # Test search filter
        search_res = self.client.get("/api/credits/?search=Juan")
        self.assertEqual(search_res.status_code, status.HTTP_200_OK)
        self.assertTrue(any(c["id"] == credit_id for c in search_res.data))

        # Test search filter not found
        search_res2 = self.client.get("/api/credits/?search=NonExistent")
        self.assertEqual(search_res2.status_code, status.HTTP_200_OK)
        self.assertFalse(any(c["id"] == credit_id for c in search_res2.data))

    def test_credit_validation_and_overpayment_rejection(self):
        self.client.force_authenticate(user=self.owner)
        # Attempt to create with 0 amount and no items
        bad_res = self.client.post(
            "/api/credits/",
            data={"customer_name": "Zero Test", "total_amount": "0.00"},
            format="json",
        )
        self.assertEqual(bad_res.status_code, status.HTTP_400_BAD_REQUEST)

        # Create valid credit
        res = self.client.post(
            "/api/credits/",
            data={"customer_name": "Valid Test", "total_amount": "100.00"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        credit_id = res.data["id"]

        # Overpayment rejection (paying 150 on 100 balance)
        overpay_res = self.client.post(
            f"/api/credits/{credit_id}/add_payment/",
            data={"amount": "150.00"},
            format="json",
        )
        self.assertEqual(overpay_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cannot exceed the remaining balance", overpay_res.data["error"])

    def test_customer_forbidden_from_credits(self):
        self.client.force_authenticate(user=self.customer)
        # GET forbidden
        get_res = self.client.get("/api/credits/")
        self.assertEqual(get_res.status_code, status.HTTP_403_FORBIDDEN)
        # POST forbidden
        post_res = self.client.post(
            "/api/credits/",
            data={"customer_name": "Hacker Customer", "total_amount": "50.00"},
            format="json",
        )
        self.assertEqual(post_res.status_code, status.HTTP_403_FORBIDDEN)


class CreditReminderCommandAndNotificationTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="reminder_owner@test.com",
            email="reminder_owner@test.com",
            password="password123",
            business_name="Reminder Store",
            role="owner",
            fcm_token="fake_fcm_token_owner_12345",
        )

    def test_notify_credit_reminder_advance_notice(self):
        from datetime import date
        from api.fcm import notify_credit_reminder
        from sales.models import CustomerCredit
        from unittest.mock import patch

        # Due on Friday
        friday_date = date(2026, 9, 25)
        credit = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Maria Santos",
            total_amount=Decimal("350.00"),
            due_date=friday_date,
        )

        with patch("api.fcm.send_push_notification") as mock_send:
            mock_send.return_value = True
            success = notify_credit_reminder(credit, "due_soon", days_offset=3)
            self.assertTrue(success)
            mock_send.assert_called_once()
            args, _ = mock_send.call_args
            token, title, body, payload = args
            self.assertEqual(token, self.owner.fcm_token)
            self.assertEqual(title, "Upcoming Utang")
            self.assertEqual(body, "Maria Santos has a balance of ₱350 due in 3 days (Friday).")
            self.assertEqual(payload["channel_id"], "stora_owner_utang")
            self.assertEqual(payload["reminder_type"], "due_soon")

    def test_notify_credit_reminder_due_today(self):
        from datetime import date
        from api.fcm import notify_credit_reminder
        from sales.models import CustomerCredit
        from unittest.mock import patch

        today_date = date(2026, 9, 28)
        credit = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Juan Dela Cruz",
            total_amount=Decimal("500.00"),
            due_date=today_date,
        )

        with patch("api.fcm.send_push_notification") as mock_send:
            mock_send.return_value = True
            success = notify_credit_reminder(credit, "due_today", days_offset=0)
            self.assertTrue(success)
            mock_send.assert_called_once()
            args, _ = mock_send.call_args
            token, title, body, payload = args
            self.assertEqual(token, self.owner.fcm_token)
            self.assertEqual(title, "Due Today")
            self.assertEqual(body, "Juan Dela Cruz owes ₱500 due today!")
            self.assertEqual(payload["channel_id"], "stora_owner_utang")
            self.assertEqual(payload["reminder_type"], "due_today")

    def test_notify_credit_reminder_overdue_alert(self):
        from datetime import date
        from api.fcm import notify_credit_reminder
        from sales.models import CustomerCredit
        from unittest.mock import patch

        due_date = date(2026, 9, 26)
        credit = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Pedro",
            total_amount=Decimal("1200.00"),
            due_date=due_date,
        )

        with patch("api.fcm.send_push_notification") as mock_send:
            mock_send.return_value = True
            success = notify_credit_reminder(credit, "overdue", days_offset=2)
            self.assertTrue(success)
            mock_send.assert_called_once()
            args, _ = mock_send.call_args
            token, title, body, payload = args
            self.assertEqual(token, self.owner.fcm_token)
            self.assertEqual(title, "🚨 Overdue Loan")
            self.assertEqual(body, "Pedro's utang of ₱1,200 is now 2 days overdue.")
            self.assertEqual(payload["channel_id"], "stora_owner_utang")
            self.assertEqual(payload["reminder_type"], "overdue")

    def test_send_credit_reminders_management_command(self):
        from datetime import date
        from io import StringIO
        from django.core.management import call_command
        from sales.models import CustomerCredit
        from unittest.mock import patch

        ref_date = "2026-09-28"  # Monday

        # 1. Due in 3 days (Thursday 2026-10-01)
        c_due_soon = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Maria Santos",
            total_amount=Decimal("350.00"),
            due_date=date(2026, 10, 1),
        )

        # 2. Due today (2026-09-28)
        c_due_today = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Juan Dela Cruz",
            total_amount=Decimal("500.00"),
            due_date=date(2026, 9, 28),
        )

        # 3. Overdue by 2 days (2026-09-26)
        c_overdue = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Pedro",
            total_amount=Decimal("1200.00"),
            due_date=date(2026, 9, 26),
        )

        # 4. Fully paid (should be ignored)
        c_paid = CustomerCredit.objects.create(
            owner=self.owner,
            customer_name="Paid Customer",
            total_amount=Decimal("100.00"),
            amount_paid=Decimal("100.00"),
            status=CustomerCredit.STATUS_SETTLED,
            due_date=date(2026, 9, 28),
        )

        out = StringIO()
        with patch("sales.management.commands.send_credit_reminders.notify_credit_reminder") as mock_notify:
            mock_notify.return_value = True
            call_command("send_credit_reminders", date=ref_date, stdout=out)

            self.assertEqual(mock_notify.call_count, 3)
            output = out.getvalue()
            self.assertIn("3 qualifying utang records found", output)
            self.assertIn("1 due in 3 days", output)
            self.assertIn("1 due today", output)
            self.assertIn("1 overdue", output)
            self.assertIn("Pushes dispatched: 3", output)





