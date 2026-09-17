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
