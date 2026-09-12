from datetime import timedelta

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.utils import timezone
from django.test import Client, TestCase
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import EmailVerificationCode, PasswordResetToken
from inventory.models import Category, Product
from orders.models import Order, OrderItem

User = get_user_model()


class AssignedPermissionTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="owner@example.com",
            email="owner@example.com",
            password="secret12",
            business_name="Test Store",
        )
        self.category = Category.objects.create(owner=self.user, name="Snacks")
        self._auth(self.user)

    def _auth(self, user):
        token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def _product_payload(self, name="Chips"):
        return {
            "name": name,
            "category": self.category.pk,
            "price": "10.00",
            "stock": 5,
        }

    def test_removing_add_product_blocks_create(self):
        allowed = self.client.post("/api/products/", self._product_payload(), format="json")
        self.assertEqual(allowed.status_code, 201, allowed.data)

        perm = Permission.objects.get(
            codename="add_product", content_type__app_label="inventory"
        )
        self.user.user_permissions.remove(perm)
        self.user = User.objects.get(pk=self.user.pk)
        self._auth(self.user)

        blocked = self.client.post(
            "/api/products/", self._product_payload("Candy"), format="json"
        )
        self.assertEqual(blocked.status_code, 403)

    def test_removing_all_permissions_blocks_list(self):
        self.user.user_permissions.clear()
        self.user = User.objects.get(pk=self.user.pk)
        self._auth(self.user)
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, 403)


class FreePlanAndTimezoneTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="free@example.com",
            email="free@example.com",
            password="secret12",
            business_name="Free Store",
        )
        token = RefreshToken.for_user(self.user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_account_status_reports_20_product_limit_and_14_day_trial(self):
        response = self.client.get("/api/account/status/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["product_limit"], 20)
        self.assertTrue(response.data["can_add_product"])
        self.assertGreaterEqual(response.data["days_left"], 13)
        self.assertLessEqual(response.data["days_left"], 14)
        self.assertTrue(response.data["trial_ends_at"].endswith("Z"))
        self.assertTrue(response.data["trial_started_at"].endswith("Z"))

    def test_expired_trial_cannot_add_product(self):
        self.user.date_joined = timezone.now() - timedelta(days=15)
        self.user.save(update_fields=["date_joined"])
        category = Category.objects.create(owner=self.user, name="Drinks")
        response = self.client.post(
            "/api/products/",
            {
                "name": "Soda",
                "category": category.pk,
                "price": "15.00",
                "stock": 2,
            },
            format="json",
        )
        self.assertEqual(response.status_code, 403)

    def test_sale_date_is_iso8601_utc(self):
        category = Category.objects.create(owner=self.user, name="Snacks")
        product = Product.objects.create(
            owner=self.user, category=category, name="Chips", price="10.00", stock=5
        )
        response = self.client.post(
            "/api/sales/",
            {"items": [{"product": product.pk, "quantity": 1}]},
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data["date"].endswith("Z"))
        listed = self.client.get("/api/sales/")
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data[0]["date"].endswith("Z"))


class AuthAndPaymentProofTests(APITestCase):
    def test_register_and_login_update_last_login(self):
        from accounts.models import PendingRegistration

        # Register - creates PendingRegistration, does NOT create User yet
        reg_resp = self.client.post(
            "/api/auth/register/",
            {
                "email": "newowner@example.com",
                "password": "password123",
                "business_name": "New Mart",
            },
            format="json",
        )
        self.assertEqual(reg_resp.status_code, 201)
        self.assertFalse(User.objects.filter(email="newowner@example.com").exists())
        pending = PendingRegistration.objects.get(email="newowner@example.com")
        self.assertEqual(len(pending.code), 6)

        # Verify email - creates User and updates last login
        ver_resp = self.client.post(
            "/api/auth/verify-email/",
            {"email": "newowner@example.com", "code": pending.code},
            format="json",
        )
        self.assertEqual(ver_resp.status_code, 200)
        user = User.objects.get(email="newowner@example.com")
        self.assertTrue(user.is_email_verified)
        self.assertIsNotNone(user.last_login)
        reg_last_login = user.last_login

        # Login
        login_resp = self.client.post(
            "/api/auth/login/",
            {"email": "newowner@example.com", "password": "password123"},
            format="json",
        )
        self.assertEqual(login_resp.status_code, 200)
        user.refresh_from_db()
        self.assertGreaterEqual(user.last_login, reg_last_login)

    def test_upload_payment_proof_and_status(self):
        import io
        from PIL import Image
        from accounts.models import PaymentProof

        user = User.objects.create_user(
            username="gcash@example.com",
            email="gcash@example.com",
            password="password123",
            business_name="GCash Store",
        )
        token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

        # Create dummy image in-memory
        image_io = io.BytesIO()
        image = Image.new("RGB", (100, 100), color="blue")
        image.save(image_io, format="JPEG")
        image_io.seek(0)
        image_io.name = "screenshot.jpg"

        upload_resp = self.client.post(
            "/api/subscription/upload-proof/",
            {
                "reference_number": "REF-12345678",
                "amount": "299.00",
                "screenshot": image_io,
            },
            format="multipart",
        )
        self.assertEqual(upload_resp.status_code, 201, upload_resp.data)
        self.assertEqual(upload_resp.data["status"], "pending")
        self.assertEqual(upload_resp.data["reference_number"], "REF-12345678")

        # Check account/status and subscription/status
        status_resp = self.client.get("/api/subscription/status/")
        self.assertEqual(status_resp.status_code, 200)
        proof_data = status_resp.data["latest_payment_proof"]
        self.assertIsNotNone(proof_data)
        self.assertEqual(proof_data["status"], "pending")
        self.assertEqual(proof_data["reference_number"], "REF-12345678")

        # Test admin approval logic
        proof = PaymentProof.objects.get(pk=upload_resp.data["id"])
        from accounts.admin import PaymentProofAdmin
        from stora_backend.admin_site import stora_admin_site

        admin_instance = PaymentProofAdmin(PaymentProof, stora_admin_site)
        from django.test import RequestFactory
        from django.contrib.messages.storage.fallback import FallbackStorage
        factory = RequestFactory()
        req = factory.get("/admin/")
        req.user = user
        setattr(req, "session", {})
        setattr(req, "_messages", FallbackStorage(req))

        admin_instance.approve_selected(req, PaymentProof.objects.filter(pk=proof.pk))
        proof.refresh_from_db()
        user.refresh_from_db()
        self.assertEqual(proof.status, "approved")
        self.assertIsNotNone(proof.reviewed_at)
        self.assertTrue(user.is_premium)
        self.assertIsNotNone(user.premium_until)
        self.assertGreater(user.premium_until, timezone.now())

        # Test stacking renewal
        old_until = user.premium_until
        admin_instance.approve_selected(req, PaymentProof.objects.filter(pk=proof.pk))
        user.refresh_from_db()
        self.assertAlmostEqual(
            (user.premium_until - old_until).total_seconds(),
            timedelta(days=31).total_seconds(),
            delta=60,
        )


class ProfileAndSubscriptionConfigTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="profile@example.com",
            email="profile@example.com",
            password="oldpassword123",
            business_name="Original Name",
        )
        token = RefreshToken.for_user(self.user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_update_profile(self):
        response = self.client.patch(
            "/api/auth/me/",
            {"business_name": "Updated Store", "email": "updated@example.com"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["business_name"], "Updated Store")
        self.assertEqual(response.data["email"], "updated@example.com")
        self.user.refresh_from_db()
        self.assertEqual(self.user.business_name, "Updated Store")
        self.assertEqual(self.user.email, "updated@example.com")

    def test_change_password(self):
        response = self.client.post(
            "/api/auth/change-password/",
            {"old_password": "oldpassword123", "new_password": "newpassword456"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("newpassword456"))

    def test_subscription_config_and_account_status(self):
        from accounts.models import SubscriptionConfig
        config = SubscriptionConfig.get_config()
        config.monthly_price = 85.00
        config.gcash_number = "0918 123 4567"
        config.gcash_name = "Admin Test"
        config.save()

        response = self.client.get("/api/subscription/config/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(float(response.data["monthly_price"]), 85.00)
        self.assertEqual(response.data["gcash_number"], "0918 123 4567")

        status_resp = self.client.get("/api/account/status/")
        self.assertEqual(status_resp.status_code, 200)
        self.assertEqual(float(status_resp.data["monthly_price"]), 85.00)
        self.assertEqual(status_resp.data["gcash_number"], "0918 123 4567")
        self.assertEqual(status_resp.data["gcash_name"], "Admin Test")

    def test_non_premium_products_limited_to_20(self):
        category = Category.objects.create(owner=self.user, name="General")
        # Create 25 products
        for i in range(25):
            Product.objects.create(
                owner=self.user,
                category=category,
                name=f"Product {i+1}",
                price="10.00",
                stock=5,
            )

        # Free user query returns at most 20 products
        resp = self.client.get("/api/products/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 20)

        # Once premium, returns all 25 products
        self.user.is_premium = True
        self.user.premium_until = timezone.now() + timedelta(days=31)
        self.user.save()

        prem_resp = self.client.get("/api/products/")
        self.assertEqual(prem_resp.status_code, 200)
        self.assertEqual(len(prem_resp.data), 25)


class OrderAndRoleIntegrityTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="storeowner@example.com",
            email="storeowner@example.com",
            password="secretpassword",
            business_name="Super Store",
            role="owner",
        )
        self.customer = User.objects.create_user(
            username="shopper@example.com",
            email="shopper@example.com",
            password="secretpassword",
            role="customer",
        )
        self.category = Category.objects.create(owner=self.owner, name="Beverages")
        self.product = Product.objects.create(
            owner=self.owner,
            category=self.category,
            name="Soda Can",
            price="2.50",
            stock=10,
        )

    def _auth(self, user):
        token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_customer_has_no_store_permissions(self):
        self.assertFalse(self.customer.has_perm("inventory.add_product"))
        self.assertFalse(self.customer.has_perm("sales.view_sale"))
        self.assertTrue(self.owner.has_perm("inventory.add_product"))
        self.assertTrue(self.owner.has_perm("sales.view_sale"))

    def test_customer_cannot_access_sales_endpoint(self):
        self._auth(self.customer)
        response = self.client.get("/api/sales/")
        self.assertEqual(response.status_code, 403)

    def test_order_expiry_in_future(self):
        order = Order.objects.create(owner=self.owner, customer=self.customer)
        self.assertFalse(order.is_expired())
        self.assertGreater(order.expires_at, timezone.now() + timedelta(hours=23))

    def test_order_accept_insufficient_stock_fails(self):
        order = Order.objects.create(owner=self.owner, customer=self.customer)
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name="Soda Can",
            quantity=15,
            unit_price="2.50",
        )
        self._auth(self.owner)
        response = self.client.post(f"/api/orders/{order.pk}/accept/")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Insufficient stock", response.data["error"])
        order.refresh_from_db()
        self.assertEqual(order.status, Order.STATUS_PENDING)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock, 10)

    def test_order_accept_sufficient_stock_decrements_and_creates_sale(self):
        order = Order.objects.create(owner=self.owner, customer=self.customer)
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name="Soda Can",
            quantity=4,
            unit_price="2.50",
        )
        self._auth(self.owner)
        response = self.client.post(f"/api/orders/{order.pk}/accept/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "accepted")
        order.refresh_from_db()
        self.assertEqual(order.status, Order.STATUS_ACCEPTED)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock, 6)
        self.assertIsNotNone(response.data["sale_id"])


class FCMNotificationTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="fcm_owner@example.com",
            email="fcm_owner@example.com",
            password="password123",
            business_name="FCM Store",
            role="owner",
            fcm_token="fake_owner_fcm_token_12345",
        )
        self.customer = User.objects.create_user(
            username="fcm_cust@example.com",
            email="fcm_cust@example.com",
            password="password123",
            role="customer",
            fcm_token="fake_cust_fcm_token_67890",
        )

    def test_send_push_notification_empty_token(self):
        from api.fcm import send_push_notification
        result = send_push_notification("", "Title", "Body")
        self.assertFalse(result)

    def test_send_push_notification_dev_fallback(self):
        from api.fcm import send_push_notification
        # When no firebase credentials are configured, it should log simulated push and return True
        result = send_push_notification(self.owner.fcm_token, "Test Title", "Test Body", {"order_id": 123})
        self.assertTrue(result)

    def test_notify_order_status_change(self):
        from api.fcm import notify_order_status_change
        from orders.models import Order

        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Customer Jane",
            customer_phone="09123456789",
            customer_address="123 Main St",
        )

        # Notify creation -> Targets owner
        notify_order_status_change(order, "created")

        # Notify acceptance -> Targets customer
        notify_order_status_change(order, "accepted")

        # Notify decline -> Targets customer
        order.decline_reason = "Out of stock"
        order.save()
        notify_order_status_change(order, "declined")

        # Notify counter -> Targets customer
        order.counter_price = 50.0
        order.counter_notes = "Discount applied"
        order.save()
        notify_order_status_change(order, "counter")


class AdminPasswordResetViewTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_admin_login_renders_successfully(self):
        response = self.client.get("/admin/login/?next=/admin/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Log in to Stora Admin")
        self.assertContains(response, "/admin/password_reset/")

    def test_admin_password_reset_views_render(self):
        reset_res = self.client.get("/admin/password_reset/")
        self.assertEqual(reset_res.status_code, 200)

        done_res = self.client.get("/admin/password_reset/done/")
        self.assertEqual(done_res.status_code, 200)

        confirm_res = self.client.get("/reset/MQ/set-password/")
        self.assertEqual(confirm_res.status_code, 200)

        complete_res = self.client.get("/reset/done/")
        self.assertEqual(complete_res.status_code, 200)


class RoleAndSubscriptionPermissionsTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin_test@stora.app",
            email="admin_test@stora.app",
            password="adminpassword123",
            role="admin",
        )
        self.owner = User.objects.create_user(
            username="owner_test@stora.app",
            email="owner_test@stora.app",
            password="ownerpassword123",
            business_name="Owner Store",
            role="owner",
        )
        self.customer = User.objects.create_user(
            username="customer_test@stora.app",
            email="customer_test@stora.app",
            password="customerpassword123",
            role="customer",
        )
        self.category = Category.objects.create(owner=self.owner, name="Snacks")
        self.product = Product.objects.create(
            owner=self.owner,
            category=self.category,
            name="Chips",
            price="1.50",
            stock=20,
        )

    def _auth(self, user):
        token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_admin_role_attributes_and_staff_access(self):
        self.assertTrue(self.admin.is_admin_role)
        self.assertTrue(self.admin.is_staff)
        self.assertTrue(self.admin.has_full_access)
        self.assertTrue(self.admin.is_premium_active)

    def test_customer_has_no_subscription_trials(self):
        self.assertIsNone(self.customer.trial_ends_at)
        self.assertFalse(self.customer.is_trial_active)
        self.assertEqual(self.customer.days_left, 0)
        self.assertTrue(self.customer.has_full_access)

        self._auth(self.customer)
        res = self.client.get("/api/account/status/")
        self.assertEqual(res.status_code, 200)
        self.assertIsNone(res.data["trial_ends_at"])
        self.assertFalse(res.data["is_premium"])

    def test_customer_catalog_read_allowed_write_denied(self):
        self._auth(self.customer)
        # Reading categories and products is allowed
        cat_res = self.client.get("/api/categories/")
        self.assertEqual(cat_res.status_code, 200)

        prod_res = self.client.get("/api/products/")
        self.assertEqual(prod_res.status_code, 200)

        # Creating category is denied for customer
        create_cat = self.client.post("/api/categories/", {"name": "Hacked Category"})
        self.assertEqual(create_cat.status_code, 403)

        # Creating product is denied for customer
        create_prod = self.client.post("/api/products/", {"name": "Hacked Product", "price": "10.00", "stock": 5})
        self.assertEqual(create_prod.status_code, 403)

    def test_customer_cannot_upload_payment_proof(self):
        self._auth(self.customer)
        res = self.client.post("/api/subscription/upload-proof/", {"reference_number": "12345", "amount": "70.00"})
        self.assertEqual(res.status_code, 403)

    def test_password_reset_request_creates_token_and_sends_mail(self):
        from django.core import mail
        res = self.client.post("/api/auth/forgot-password/", {"email": "customer_test@stora.app"})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(PasswordResetToken.objects.filter(user=self.customer, used=False).exists())
        token_obj = PasswordResetToken.objects.filter(user=self.customer, used=False).first()
        self.assertTrue(token_obj.is_valid())
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(str(token_obj.token), mail.outbox[0].body)


class EmailVerificationTests(APITestCase):
    def test_registration_with_gmail_sends_verification_code(self):
        from django.core import mail
        from accounts.models import PendingRegistration
        mail.outbox.clear()
        payload = {
            "email": "newowner@gmail.com",
            "password": "strongpassword123",
            "business_name": "New Owner Store",
            "role": "owner",
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, 201)

        # User is NOT created yet
        self.assertFalse(User.objects.filter(email="newowner@gmail.com").exists())
        self.assertFalse(res.data["is_email_verified"])
        self.assertIn("verification code", res.data["message"].lower())

        # PendingRegistration record created
        pending = PendingRegistration.objects.get(email="newowner@gmail.com")
        self.assertEqual(len(pending.code), 6)
        self.assertTrue(pending.is_valid())

        # Email dispatched to Gmail inbox
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(pending.code, mail.outbox[0].body)
        self.assertIn("Verification Code", mail.outbox[0].subject)

        # Now verify the code -> User is created
        ver_res = self.client.post(
            "/api/auth/verify-email/",
            {"email": "newowner@gmail.com", "code": pending.code},
            format="json",
        )
        self.assertEqual(ver_res.status_code, 200)
        user = User.objects.get(email="newowner@gmail.com")
        self.assertTrue(user.is_email_verified)
        self.assertIn("access", ver_res.data)

    def test_registration_with_non_gmail_creates_verification_code_and_sends_email(self):
        from django.core import mail
        from accounts.models import PendingRegistration
        mail.outbox.clear()
        payload = {
            "email": "newowner@yahoo.com",
            "password": "strongpassword123",
            "business_name": "New Owner Store",
            "role": "owner",
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, 201)

        # User is NOT created yet
        self.assertFalse(User.objects.filter(email="newowner@yahoo.com").exists())
        self.assertFalse(res.data["is_email_verified"])

        # PendingRegistration created
        pending = PendingRegistration.objects.get(email="newowner@yahoo.com")
        self.assertEqual(len(pending.code), 6)
        self.assertTrue(pending.is_valid())

        # Email dispatched
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(pending.code, mail.outbox[0].body)
        self.assertIn("Verification Code", mail.outbox[0].subject)

    def test_verify_email_with_valid_code_succeeds(self):
        user = User.objects.create_user(
            username="verify_test@gmail.com",
            email="verify_test@gmail.com",
            password="testpassword123",
            is_email_verified=False,
        )
        code_obj = EmailVerificationCode.generate_code(user)

        res = self.client.post(
            "/api/auth/verify-email/",
            {"email": "verify_test@gmail.com", "code": code_obj.code},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data["user"]["is_email_verified"])

        user.refresh_from_db()
        self.assertTrue(user.is_email_verified)

        code_obj.refresh_from_db()
        self.assertTrue(code_obj.used)

    def test_verify_email_with_invalid_code_fails(self):
        user = User.objects.create_user(
            username="invalid_test@gmail.com",
            email="invalid_test@gmail.com",
            password="testpassword123",
            is_email_verified=False,
        )
        EmailVerificationCode.generate_code(user)

        res = self.client.post(
            "/api/auth/verify-email/",
            {"email": "invalid_test@gmail.com", "code": "999999"},
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data["detail"], "Invalid verification code.")

        user.refresh_from_db()
        self.assertFalse(user.is_email_verified)

    def test_verify_email_with_expired_code_fails(self):
        user = User.objects.create_user(
            username="expired_test@gmail.com",
            email="expired_test@gmail.com",
            password="testpassword123",
            is_email_verified=False,
        )
        code_obj = EmailVerificationCode.generate_code(user)
        code_obj.expires_at = timezone.now() - timedelta(minutes=5)
        code_obj.save()

        res = self.client.post(
            "/api/auth/verify-email/",
            {"email": "expired_test@gmail.com", "code": code_obj.code},
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("expired", res.data["detail"].lower())

    def test_resend_verification_code_cooldown_and_dispatch(self):
        from django.core import mail
        mail.outbox.clear()
        user = User.objects.create_user(
            username="resend_test@gmail.com",
            email="resend_test@gmail.com",
            password="testpassword123",
            is_email_verified=False,
        )
        first_code = EmailVerificationCode.generate_code(user)

        # Immediate resend should trigger 429 Too Many Requests cooldown
        cooldown_res = self.client.post(
            "/api/auth/resend-verification/",
            {"email": "resend_test@gmail.com"},
            format="json",
        )
        self.assertEqual(cooldown_res.status_code, 429)

        # Push first code timestamp back by 65 seconds
        first_code.created_at = timezone.now() - timedelta(seconds=65)
        first_code.save()

        # Resend should now succeed
        success_res = self.client.post(
            "/api/auth/resend-verification/",
            {"email": "resend_test@gmail.com"},
            format="json",
        )
        self.assertEqual(success_res.status_code, 200)

        # Old code marked used/invalidated and new code active
        first_code.refresh_from_db()
        self.assertTrue(first_code.used)

        new_code = EmailVerificationCode.objects.filter(user=user, used=False).first()
        self.assertIsNotNone(new_code)
        self.assertNotEqual(first_code.code, new_code.code)
        self.assertEqual(len(mail.outbox), 1)

    def test_profile_update_resets_email_verification(self):
        user = User.objects.create_user(
            username="user_update@gmail.com",
            email="user_update@gmail.com",
            password="testpassword123",
            is_email_verified=True,
        )
        self.client.force_authenticate(user=user)

        # Update to new email -> should reset is_email_verified to False
        res = self.client.patch(
            "/api/auth/me/",
            {"email": "user_update2@gmail.com"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        user.refresh_from_db()
        self.assertEqual(user.email, "user_update2@gmail.com")
        self.assertEqual(user.username, "user_update2@gmail.com")
        self.assertFalse(user.is_email_verified)


class GmailCanonicalizationTests(APITestCase):
    def test_gmail_dots_and_plus_collapse_to_single_account(self):
        from accounts.models import PendingRegistration

        # Register with dots in username -> stored canonically in PendingRegistration
        res = self.client.post(
            "/api/auth/register/",
            {
                "email": "Juan.Dela.Cruz@gmail.com",
                "password": "strongpassword123",
                "business_name": "Juan Store",
                "role": "owner",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertFalse(User.objects.filter(email="juandelacruz@gmail.com").exists())
        pending = PendingRegistration.objects.get(email="juandelacruz@gmail.com")
        self.assertEqual(pending.email, "juandelacruz@gmail.com")

        # Attempting to register with plus-alias should be REJECTED (already exists in Pending)
        res_plus = self.client.post(
            "/api/auth/register/",
            {
                "email": "juandelacruz+freetrial@gmail.com",
                "password": "otherpassword123",
                "business_name": "Another Store",
                "role": "owner",
            },
            format="json",
        )
        self.assertEqual(res_plus.status_code, 400)
        self.assertIn("already exists", str(res_plus.data))

        # Attempting to register with googlemail domain alias should be REJECTED
        res_googlemail = self.client.post(
            "/api/auth/register/",
            {
                "email": "j.u.a.n.delacruz@googlemail.com",
                "password": "otherpassword123",
                "business_name": "Another Store",
                "role": "owner",
            },
            format="json",
        )
        self.assertEqual(res_googlemail.status_code, 400)
        self.assertIn("already exists", str(res_googlemail.data))

    def test_login_with_gmail_alias_logs_into_canonical_account(self):
        User.objects.create_user(
            username="mariaclara@gmail.com",
            email="mariaclara@gmail.com",
            password="testpassword123",
            is_email_verified=True,
        )

        # Log in using dotted alias with plus tag
        res = self.client.post(
            "/api/auth/login/",
            {
                "email": "maria.clara+store@gmail.com",
                "password": "testpassword123",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["user"]["email"], "mariaclara@gmail.com")

    def test_non_gmail_preserves_dots_and_pluses(self):
        from accounts.models import PendingRegistration
        res = self.client.post(
            "/api/auth/register/",
            {
                "email": "john.doe@yahoo.com",
                "password": "strongpassword123",
                "business_name": "Yahoo Store",
                "role": "owner",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        pending = PendingRegistration.objects.get(email="john.doe@yahoo.com")
        self.assertEqual(pending.email, "john.doe@yahoo.com")


class AdminColumnsAndNotificationsTests(APITestCase):
    def test_admin_columns_distinguish_business_and_customer_names(self):
        from accounts.admin import UserAdmin
        from stora_backend.admin_site import stora_admin_site

        owner = User.objects.create_user(
            username="owner_col@gmail.com",
            email="owner_col@gmail.com",
            password="pass",
            role="owner",
            business_name="Aling Nena Store",
        )
        customer = User.objects.create_user(
            username="cust_col@gmail.com",
            email="cust_col@gmail.com",
            password="pass",
            role="customer",
            business_name="Juan Dela Cruz",
        )

        user_admin = UserAdmin(User, stora_admin_site)
        self.assertIn("Aling Nena Store", str(user_admin.owner_customer_name(owner)))
        self.assertIn("Juan Dela Cruz", str(user_admin.owner_customer_name(customer)))

    def test_notify_admin_dispatches_when_admin_has_fcm_token(self):
        from api.fcm import notify_admin

        admin_user = User.objects.create_user(
            username="sysadmin@example.com",
            email="sysadmin@example.com",
            password="pass",
            role="admin",
            fcm_token="admin_fcm_token_12345",
        )
        sent = notify_admin("Test Admin Alert", "Something happened")
        self.assertEqual(sent, 1)


class EmailRoleExclusivityTests(APITestCase):
    def test_customer_email_cannot_register_or_login_as_owner(self):
        # Create an existing customer account
        User.objects.create_user(
            username="customer1@example.com",
            email="customer1@example.com",
            password="password123",
            role="customer",
            business_name="Cust Name",
            is_email_verified=True,
        )

        # Attempt to register the same email in owner app
        res = self.client.post(
            "/api/auth/register/",
            {
                "email": "customer1@example.com",
                "password": "password123",
                "business_name": "Store Attempt",
                "role": "owner",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("registered as a Customer account", str(res.data))

        # Attempt to log into owner app with customer credentials
        res_login = self.client.post(
            "/api/auth/login/",
            {
                "email": "customer1@example.com",
                "password": "password123",
                "app_role": "owner",
            },
            format="json",
        )
        self.assertEqual(res_login.status_code, 400)
        self.assertIn("registered as a Customer", str(res_login.data))

    def test_owner_email_cannot_register_or_login_as_customer(self):
        # Create an existing store owner account
        User.objects.create_user(
            username="owner1@example.com",
            email="owner1@example.com",
            password="password123",
            role="owner",
            business_name="Owner Store",
            is_email_verified=True,
        )

        # Attempt to register the same email in customer app
        res = self.client.post(
            "/api/auth/register/",
            {
                "email": "owner1@example.com",
                "password": "password123",
                "business_name": "Customer Attempt",
                "role": "customer",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("registered as a Store Owner account", str(res.data))

        # Attempt to log into customer app with owner credentials
        res_login = self.client.post(
            "/api/auth/login/",
            {
                "email": "owner1@example.com",
                "password": "password123",
                "app_role": "customer",
            },
            format="json",
        )
        self.assertEqual(res_login.status_code, 400)
        self.assertIn("registered as a Store Owner", str(res_login.data))


class ChatAndMessagingTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="store_owner@example.com",
            email="store_owner@example.com",
            password="password123",
            role="owner",
            business_name="My Sari-Sari Store",
            fcm_token="owner_fcm_token_999",
            is_email_verified=True,
        )
        self.customer = User.objects.create_user(
            username="shopper@example.com",
            email="shopper@example.com",
            password="password123",
            role="customer",
            business_name="Juan Buyer",
            fcm_token="customer_fcm_token_888",
            is_email_verified=True,
        )

    def test_send_and_receive_messages(self):
        self.client.force_authenticate(user=self.customer)

        # Customer sends message to owner
        res = self.client.post(
            "/api/messages/",
            {"recipient": self.owner.id, "message": "Hi, do you have fresh eggs?"},
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["message"], "Hi, do you have fresh eggs?")

        # Owner checks conversation list and messages
        self.client.force_authenticate(user=self.owner)
        conv_res = self.client.get("/api/messages/conversations/")
        self.assertEqual(conv_res.status_code, 200)
        self.assertEqual(len(conv_res.data), 1)
        self.assertEqual(conv_res.data[0]["user_id"], self.customer.id)
        self.assertEqual(conv_res.data[0]["unread_count"], 1)

        # Owner views message thread -> marks unread as read
        msg_res = self.client.get(f"/api/messages/?with_user={self.customer.id}")
        self.assertEqual(msg_res.status_code, 200)
        self.assertEqual(len(msg_res.data), 1)
        self.assertTrue(msg_res.data[0]["is_read"])

    def test_block_and_unblock_customer(self):
        self.client.force_authenticate(user=self.owner)

        # Owner blocks customer
        block_res = self.client.post(
            "/api/messages/block/",
            {"customer_id": self.customer.id},
            format="json",
        )
        self.assertEqual(block_res.status_code, 200)
        self.assertEqual(block_res.data["status"], "blocked")

        # Blocked customer tries to send message -> 403 Forbidden
        self.client.force_authenticate(user=self.customer)
        blocked_send = self.client.post(
            "/api/messages/",
            {"recipient": self.owner.id, "message": "Can I order?"},
            format="json",
        )
        self.assertEqual(blocked_send.status_code, 403)
        self.assertIn("blocked", str(blocked_send.data))

        # Owner unblocks customer
        self.client.force_authenticate(user=self.owner)
        unblock_res = self.client.post(
            "/api/messages/unblock/",
            {"customer_id": self.customer.id},
            format="json",
        )
        self.assertEqual(unblock_res.status_code, 200)
        self.assertEqual(unblock_res.data["status"], "unblocked")

        # Now customer can send message
        self.client.force_authenticate(user=self.customer)
        allowed_send = self.client.post(
            "/api/messages/",
            {"recipient": self.owner.id, "message": "Thank you for unblocking!"},
            format="json",
        )
        self.assertEqual(allowed_send.status_code, 201)


class PendingOrderWallTests(APITestCase):
    def test_store_owners_only_see_their_own_orders(self):
        owner_a = User.objects.create_user(
            username="shop_a@example.com",
            email="shop_a@example.com",
            password="pass",
            role="owner",
            business_name="Shop A",
            is_email_verified=True,
        )
        owner_b = User.objects.create_user(
            username="shop_b@example.com",
            email="shop_b@example.com",
            password="pass",
            role="owner",
            business_name="Shop B",
            is_email_verified=True,
        )
        customer = User.objects.create_user(
            username="buyer@example.com",
            email="buyer@example.com",
            password="pass",
            role="customer",
            business_name="Buyer Juan",
            is_email_verified=True,
        )

        from orders.models import Order
        order_a = Order.objects.create(owner=owner_a, customer=customer, customer_name="Buyer Juan")
        order_b = Order.objects.create(owner=owner_b, customer=customer, customer_name="Buyer Juan")

        # Authenticate as Shop A -> only sees order_a
        self.client.force_authenticate(user=owner_a)
        res_a = self.client.get("/api/orders/")
        self.assertEqual(res_a.status_code, 200)
        order_ids_a = [o["id"] for o in res_a.data]
        self.assertIn(order_a.id, order_ids_a)
        self.assertNotIn(order_b.id, order_ids_a)

        # Authenticate as Shop B -> only sees order_b
        self.client.force_authenticate(user=owner_b)
        res_b = self.client.get("/api/orders/")
        self.assertEqual(res_b.status_code, 200)
        order_ids_b = [o["id"] for o in res_b.data]
        self.assertIn(order_b.id, order_ids_b)
        self.assertNotIn(order_a.id, order_ids_b)


class UserReportingTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="shopowner_rep@gmail.com",
            email="shopowner_rep@gmail.com",
            password="testpassword123",
            role=User.ROLE_OWNER,
            business_name="Reporting Test Shop",
            is_email_verified=True,
        )
        self.customer = User.objects.create_user(
            username="customer_rep@gmail.com",
            email="customer_rep@gmail.com",
            password="testpassword123",
            role=User.ROLE_CUSTOMER,
            first_name="Reported",
            last_name="Buyer",
            is_email_verified=True,
        )

    def test_owner_can_report_customer(self):
        self.client.force_authenticate(user=self.owner)
        res = self.client.post(
            "/api/reports/",
            {
                "reported_user": self.customer.id,
                "reason": "fake_order",
                "description": "Customer placed multiple fake orders and refused to receive.",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertIn("detail", res.data)
        self.assertEqual(res.data["report"]["reason"], "fake_order")
        self.assertEqual(res.data["report"]["status"], "pending")
        self.assertEqual(res.data["report"]["reporter_email"], self.owner.email)
        self.assertEqual(res.data["report"]["reported_user_email"], self.customer.email)

    def test_customer_can_report_store_owner(self):
        self.client.force_authenticate(user=self.customer)
        res = self.client.post(
            "/api/reports/",
            {
                "reported_user": self.owner.id,
                "reason": "fraud",
                "description": "Store owner did not deliver items after counter offer.",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["report"]["reason"], "fraud")

    def test_cannot_report_oneself(self):
        self.client.force_authenticate(user=self.customer)
        res = self.client.post(
            "/api/reports/",
            {
                "reported_user": self.customer.id,
                "reason": "other",
                "description": "Reporting myself should fail.",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 400)

    def test_duplicate_pending_report_prevented(self):
        from api.models import UserReport
        UserReport.objects.create(
            reporter=self.owner,
            reported_user=self.customer,
            reason="harassment",
            description="First report",
            status=UserReport.STATUS_PENDING,
        )

        self.client.force_authenticate(user=self.owner)
        res = self.client.post(
            "/api/reports/",
            {
                "reported_user": self.customer.id,
                "reason": "harassment",
                "description": "Duplicate second report",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("already have a pending report", str(res.data))

    def test_admin_block_and_unblock_actions(self):
        from api.models import UserReport
        from api.admin import UserReportAdmin
        from django.contrib.admin.sites import AdminSite

        report = UserReport.objects.create(
            reporter=self.owner,
            reported_user=self.customer,
            reason="harassment",
            description="Harassing store staff",
            status=UserReport.STATUS_PENDING,
        )

        admin = User.objects.create_superuser(
            username="admin_mod@gmail.com",
            email="admin_mod@gmail.com",
            password="adminpassword123",
            role=User.ROLE_ADMIN,
        )

        admin_instance = UserReportAdmin(model=UserReport, admin_site=AdminSite())

        # Mock request
        class MockRequest:
            user = admin
            def __init__(self):
                self._messages = []
            def message_user(self, req, msg, **kwargs):
                self._messages.append(msg)

        req = MockRequest()
        admin_instance.message_user = req.message_user

        # Trigger block action
        admin_instance.block_reported_users(req, UserReport.objects.filter(id=report.id))
        self.customer.refresh_from_db()
        report.refresh_from_db()

        self.assertFalse(self.customer.is_active)
        self.assertEqual(report.status, UserReport.STATUS_ACTION_TAKEN)

        # Trigger unblock action
        admin_instance.unblock_reported_users(req, UserReport.objects.filter(id=report.id))
        self.customer.refresh_from_db()
        self.assertTrue(self.customer.is_active)


class CustomerNameAndEmailDisplayTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username="owner_display@gmail.com",
            email="owner_display@gmail.com",
            password="testpassword123",
            role=User.ROLE_OWNER,
            business_name="Display Test Shop",
            is_email_verified=True,
        )
        self.customer = User.objects.create_user(
            username="customer_display@gmail.com",
            email="customer_display@gmail.com",
            password="testpassword123",
            role=User.ROLE_CUSTOMER,
            business_name="Lejon Osial",
            is_email_verified=True,
        )

    def test_customer_display_name_resolves_to_business_name(self):
        self.assertEqual(self.customer.get_display_name(), "Lejon Osial")

    def test_order_serializer_includes_customer_email(self):
        from api.serializers import OrderSerializer
        order = Order.objects.create(
            owner=self.owner,
            customer=self.customer,
            customer_name="Lejon Osial",
        )
        serializer_data = OrderSerializer(order).data
        self.assertEqual(serializer_data.get("customer_name"), "Lejon Osial")
        self.assertEqual(serializer_data.get("customer_email"), "customer_display@gmail.com")

    def test_conversations_displays_customer_name_instead_of_email(self):
        from api.models import ChatMessage
        ChatMessage.objects.create(
            sender=self.customer,
            recipient=self.owner,
            message="Hello store owner",
        )
        self.client.force_authenticate(user=self.owner)
        res = self.client.get("/api/messages/conversations/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]["name"], "Lejon Osial")
        self.assertEqual(res.data[0]["email"], "customer_display@gmail.com")

    def test_owner_can_delete_conversation_via_path(self):
        from api.models import ChatMessage
        ChatMessage.objects.create(sender=self.customer, recipient=self.owner, message="Hello")
        ChatMessage.objects.create(sender=self.owner, recipient=self.customer, message="Hi there")
        self.assertEqual(ChatMessage.objects.count(), 2)

        self.client.force_authenticate(user=self.owner)
        res = self.client.delete(f"/api/messages/conversations/{self.customer.id}/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["deleted_count"], 2)
        # Soft delete: messages still exist in DB for customer
        self.assertEqual(ChatMessage.objects.count(), 2)

        # Conversations list is now empty for owner
        conv_res = self.client.get("/api/messages/conversations/")
        self.assertEqual(conv_res.status_code, 200)
        self.assertEqual(len(conv_res.data), 0)

        # But customer still sees the conversation
        self.client.force_authenticate(user=self.customer)
        cust_conv = self.client.get("/api/messages/conversations/")
        self.assertEqual(cust_conv.status_code, 200)
        self.assertEqual(len(cust_conv.data), 1)

    def test_customer_can_delete_conversation_via_query_param(self):
        from api.models import ChatMessage
        ChatMessage.objects.create(sender=self.customer, recipient=self.owner, message="Question")
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.client.force_authenticate(user=self.customer)
        res = self.client.delete(f"/api/messages/?with_user={self.owner.id}")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["deleted_count"], 1)
        # Soft delete: message still in DB for owner
        self.assertEqual(ChatMessage.objects.count(), 1)

        # Customer's conversation list is empty
        cust_res = self.client.get("/api/messages/conversations/")
        self.assertEqual(len(cust_res.data), 0)

        # Owner still has the conversation
        self.client.force_authenticate(user=self.owner)
        owner_res = self.client.get("/api/messages/conversations/")
        self.assertEqual(len(owner_res.data), 1)

    def test_delete_single_message_by_sender_and_recipient(self):
        from api.models import ChatMessage
        m1 = ChatMessage.objects.create(sender=self.owner, recipient=self.customer, message="Message 1")
        m2 = ChatMessage.objects.create(sender=self.customer, recipient=self.owner, message="Message 2")

        # Sender (owner) unsend m1
        self.client.force_authenticate(user=self.owner)
        res1 = self.client.delete(f"/api/messages/{m1.id}/?action=unsend")
        self.assertEqual(res1.status_code, 200)
        self.assertTrue(res1.data.get("is_unsent"))
        m1.refresh_from_db()
        self.assertTrue(m1.is_unsent)
        self.assertEqual(m1.message, "This message was unsent")

        # Recipient (owner) deletes m2 for me only
        res2 = self.client.delete(f"/api/messages/{m2.id}/?action=remove_for_me")
        self.assertEqual(res2.status_code, 200)
        self.assertEqual(res2.data.get("action"), "remove_for_me")
        m2.refresh_from_db()
        # Message still exists in DB
        self.assertTrue(m2.deleted_by_users.filter(id=self.owner.id).exists())
        # Customer has NOT deleted m2
        self.assertFalse(m2.deleted_by_users.filter(id=self.customer.id).exists())

    def test_delete_single_message_unauthorized(self):
        from api.models import ChatMessage
        other_user = User.objects.create_user(username="stranger", email="stranger@example.com", password="pass")
        m = ChatMessage.objects.create(sender=self.owner, recipient=self.customer, message="Private")

        self.client.force_authenticate(user=other_user)
        res = self.client.delete(f"/api/messages/{m.id}/")
        self.assertEqual(res.status_code, 403)
        self.assertTrue(ChatMessage.objects.filter(id=m.id).exists())








