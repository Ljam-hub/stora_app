from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status

from inventory.models import Category, Product
from orders.models import Order, OrderItem
from sales.models import Sale

User = get_user_model()


class OrderAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username="owner@test.com",
            email="owner@test.com",
            password="password123",
            business_name="Test Store",
            role="owner",
            fcm_token="owner_fcm_token_123",
        )
        self.customer = User.objects.create_user(
            username="customer@test.com",
            email="customer@test.com",
            password="password123",
            role="customer",
            fcm_token="customer_fcm_token_456",
        )
        self.category = Category.objects.create(name="Beverages", owner=self.owner)
        self.product = Product.objects.create(
            owner=self.owner,
            category=self.category,
            name="Iced Coffee",
            price=Decimal("120.00"),
            stock=10,
        )

    def test_create_order_by_customer(self):
        self.client.force_authenticate(user=self.customer)
        payload = {
            "owner": self.owner.id,
            "customer_name": "Juan Dela Cruz",
            "customer_phone": "09171234567",
            "customer_address": "123 Main St, Manila",
            "notes": "Extra ice please",
            "items_data": [
                {
                    "product": self.product.id,
                    "product_name": "Iced Coffee",
                    "quantity": 2,
                    "unit_price": "120.00",
                }
            ],
        }
        response = self.client.post("/api/orders/", data=payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["status"], "pending")
        self.assertEqual(response.data["total_amount"], "240.00")
        self.assertEqual(Order.objects.count(), 1)
        order = Order.objects.first()
        self.assertEqual(order.items.count(), 1)
        self.assertEqual(order.customer, self.customer)

    def test_owner_accept_order_decrements_stock_and_creates_sale(self):
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Juan Dela Cruz",
            customer_phone="09171234567",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=3,
            unit_price=Decimal("120.00"),
        )

        self.client.force_authenticate(user=self.owner)
        response = self.client.post(f"/api/orders/{order.id}/accept/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], "accepted")

        # Verify stock decremented: 10 - 3 = 7
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock, 7)

        # Verify Sale was created
        self.assertEqual(Sale.objects.count(), 1)
        sale = Sale.objects.first()
        self.assertEqual(sale.total, Decimal("360.00"))
        self.assertEqual(sale.items.count(), 1)

    def test_owner_decline_order(self):
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Juan Dela Cruz",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=1,
            unit_price=Decimal("120.00"),
        )

        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/orders/{order.id}/decline/",
            data={"reason": "Store is currently closed"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, "declined")
        self.assertEqual(order.decline_reason, "Store is currently closed")
        # Stock should NOT change
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock, 10)

    def test_owner_counter_offer(self):
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Juan Dela Cruz",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=1,
            unit_price=Decimal("120.00"),
        )

        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/orders/{order.id}/counter/",
            data={"notes": "Available in medium size only", "counter_price": "100.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, "counter_offer")
        self.assertEqual(order.counter_notes, "Available in medium size only")
        self.assertEqual(order.counter_price, Decimal("100.00"))

    def test_update_fcm_token(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.post(
            "/api/auth/fcm-token/",
            data={"fcm_token": "new_device_token_xyz"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.fcm_token, "new_device_token_xyz")
