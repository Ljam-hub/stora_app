# Stora Admin Backend

A Django backend with a customized `/admin/` plus a REST API at `/api/`
that the Flutter app talks to. Each store owner has their own
categories, products, and sales.

## What's here

- **accounts** — custom `User` model (adds `business_name`, matching the
  app's Register screen).
- **inventory** — `Category`, `Product` (mirrors `CategoryStore` /
  `InventoryStore` / `Product` in the app, including the 99-unit stock
  ceiling and the "hide category without deleting" behavior).
- **sales** — `Sale`, `SaleItem` (mirrors `SalesStore` / `Sale` /
  `CartItem`; line-item prices are snapshotted at sale time so editing a
  product later doesn't rewrite history).
- **templates/admin/**, **static/admin/css/** — override Django's default
  admin look with Stora's dark/purple theme and add dashboard summary
  cards (today's earnings, stock, low-stock count) above the model list,
  echoing the app's own Dashboard screen.

## Local Development Setup

```bash
cd stora_backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser

python manage.py runserver
```

No environment variables needed for local dev — defaults give you
SQLite, `DEBUG=True`, and permissive CORS.

Then visit `http://127.0.0.1:8000/admin/` and log in with the
superuser you just created. The Flutter app uses:

- `POST /api/auth/register/` and `POST /api/auth/login/` (JWT)
- `GET/POST /api/categories/`, `/api/products/`, `/api/sales/`

Run the API bound to all interfaces so an Android emulator can reach it:

```bash
python manage.py runserver 0.0.0.0:8000
```

---

## Deploying to Render

### One-Click (Render Blueprint)

1. Push this repo to GitHub/GitLab.
2. Go to https://render.com/deploy and point it at the repo.
3. Render reads `render.yaml` and creates the web service + Postgres
   database automatically.
4. Set the remaining env vars manually in the Render dashboard (see
   table below).

### Manual Setup

1. **Create a PostgreSQL database** on Render (free tier).
2. **Create a Web Service** pointing at this repo.
   - **Build command:** `./build.sh`
   - **Start command:** `gunicorn stora_backend.wsgi:application`
3. **Set environment variables** in the Render dashboard:

| Variable | Example | Required? |
|----------|---------|-----------|
| `SECRET_KEY` | *(generate: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`)* | **Yes** |
| `DEBUG` | `False` | **Yes** |
| `ALLOWED_HOSTS` | `stora-backend.onrender.com` | **Yes** |
| `DATABASE_URL` | *(auto-set when you link the Postgres instance)* | **Yes** |
| `CLOUDINARY_URL` | `cloudinary://KEY:SECRET@CLOUD_NAME` | **Yes** |
| `CORS_ALLOWED_ORIGINS` | `https://your-app.com` *(or leave empty for mobile-only)* | No |
| `PYTHON_VERSION` | `3.14.7` | Recommended |

### Media Storage (Product Photos)

Product images are stored via **Cloudinary** in production (Render's
filesystem is ephemeral — local files are wiped on every deploy/restart).

1. Create a free Cloudinary account at https://cloudinary.com.
2. Copy your `CLOUDINARY_URL` from the Cloudinary dashboard.
3. Set it as an environment variable in Render.

### ⚠️ Render Free-Tier Postgres Warning

> Render's free PostgreSQL databases are **deleted 90 days after
> creation**. This is not a one-time setup step — you must recreate the
> database and re-run migrations periodically, or upgrade to a paid plan.
> Set a calendar reminder.

---

## Auth Hardening (Future)

The JWT access tokens last 7 days and refresh tokens 30 days. Consider
enabling `rest_framework_simplejwt.token_blacklist` so tokens can be
revoked (e.g., if a phone is lost). This requires:

1. Add `"rest_framework_simplejwt.token_blacklist"` to `INSTALLED_APPS`
2. Run `python manage.py migrate`
3. Add a logout endpoint that blacklists the refresh token

---

## Notes

- Uses WhiteNoise to serve static files (admin CSS/JS) in production —
  no need for a separate Nginx or CDN for the admin.
- All API querysets are scoped to the authenticated user's `owner` field,
  so one business can never see another's data.
