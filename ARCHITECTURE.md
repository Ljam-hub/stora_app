# Stora Architecture & MVC Specification

## 1. Executive Summary

**Stora** adheres strictly to the **Model-View-Controller (MVC)** architectural pattern across both its client applications (Flutter mobile clients) and its backend services (Django REST Framework). 

By enforcing a clear separation of concerns, Stora ensures:
- **Modularity**: Data persistence, business rules, and UI presentations are decoupled.
- **Maintainability**: Business logic and state mutations can be refactored or unit-tested without touching UI widgets.
- **Offline Resilience**: Mobile controllers seamlessly negotiate between local offline SQLite/Drift stores and cloud REST endpoints.

---

## 2. Global Architectural Overview

```mermaid
flowchart TD
    subgraph Frontend ["Client Tier (Flutter Mobile - stora_owner & stora_customer)"]
        subgraph ViewLayer ["View (Presentation Layer)"]
            V1["Screens (e.g. PosScreen, ShopScreen)"]
            V2["Widgets (e.g. ProductCard, CartTile)"]
        end
        
        subgraph ControllerLayer ["Controller (Business & State Layer)"]
            C1["Controllers / Stores / Providers"]
            C2["(e.g. CartController, InventoryController)"]
        end
        
        subgraph ModelLayer ["Model (Data Layer)"]
            M1["Dart Models (Product, Order, Sale)"]
            M2["Local Cache / Drift SQLite Entities"]
        end
        
        V1 -->|"1. User Action (tap, scan, input)"| C1
        C1 -->|"2. Updates / Mutates"| M1
        M1 -->|"3. Notifies State Change"| C1
        C1 -->|"4. Triggers Re-render (notifyListeners)"| V1
    end

    subgraph Backend ["Server Tier (Django REST Framework - stora_backend)"]
        subgraph ServerController ["Controller (Routing & Coordination)"]
            SC1["URL Router (urls.py)"]
            SC2["API Views & ViewSets (views.py)"]
        end
        
        subgraph ServerModel ["Model (ORM & Business Entities)"]
            SM1["Django Models (Product, Order, Sale)"]
            SM2["PostgreSQL / SQLite Database"]
        end
        
        subgraph ServerView ["View (Presentation & Serialization)"]
            SV1["DRF Serializers (JSON Responses)"]
            SV2["Django Templates (Web Portal HTML)"]
        end
        
        SC1 -->|"Route Request"| SC2
        SC2 -->|"Query / Mutate"| SM1
        SM1 -->|"Database Persistence"| SM2
        SM1 -->|"Populate Data"| SV1
        SV1 -->|"Format Response"| SC2
    end

    C1 <===>|"HTTP / JSON REST API"| SC1
```

---

## 3. Subsystem Breakdown

### 3.1. Flutter Customer App (`stora_customer`)

| MVC Component | Directory / Artifact | Role & Responsibility |
| :--- | :--- | :--- |
| **Model** | `lib/models/` | Immutable data entities (`Product`, `Order`, `Store`, `CartItem`, `User`). Handles JSON parsing (`fromJson`), serializing (`toJson`), and formatting. |
| **View** | `lib/screens/`<br>`lib/widgets/` | Pure presentation UI. Renders widgets, receives gestures, and triggers controller actions. Examples: `ShopScreen`, `CartScreen`, `OrdersScreen`, `ProductCard`. |
| **Controller** | `lib/controllers/`<br>`lib/providers/` | Manages feature workflows, API networking, and UI reactive state extending `ChangeNotifier`. Examples: `CartController`, `CatalogController`, `OrderController`, `AuthController`. |

### 3.2. Flutter Owner App (`stora_owner`)

| MVC Component | Directory / Artifact | Role & Responsibility |
| :--- | :--- | :--- |
| **Model** | `lib/home/models/`<br>`lib/data/local/` | Domain representations of business entities (`Product`, `Sale`, `CartItem`, `PaymentAccount`, `OwnerNote`) and local Drift/SQLite schema tables. |
| **View** | `lib/home/screens/`<br>`lib/home/widgets/`<br>`lib/stora_login/` | Store owner UI interfaces. Displays sales graphs, POS barcode scanner, inventory tables, and utang ledgers. Examples: `PosScreen`, `InventoryListScreen`, `DashboardScreen`. |
| **Controller** | `lib/home/controllers/`<br>`lib/home/stores/`<br>`lib/data/stores/` | Orchestrates offline-first mutations, calculations (totals, debt balance, daily earnings), and sync triggers. Examples: `CartController`, `InventoryController`, `SalesController`, `UtangController`, `OrdersController`. |

### 3.3. Django Backend (`stora_backend`)

In Django's Model-View-Template (MVT) architecture (which maps 1:1 to MVC):

| MVC Component | Backend Implementation | Role & Responsibility |
| :--- | :--- | :--- |
| **Model** | `*/models.py` (`accounts`, `api`, `inventory`, `orders`, `sales`) | Defines relational tables, constraints, validation methods, foreign keys, and DB transactions. |
| **View** | `api/serializers.py`<br>`templates/` | Defines how data is represented to clients: serializes model instances into JSON payloads for mobile apps, or renders HTML templates for web admins. |
| **Controller** | `urls.py`<br>`api/views.py` | URL dispatcher maps incoming endpoints. ViewSets/APIViews authenticate requests, invoke business methods on models, and select the appropriate view serializer. |

---

## 4. MVC Lifecycle Example: POS / Cart Checkout

```mermaid
sequenceDiagram
    autonumber
    actor Merchant as Store Owner
    participant View as PosScreen (View)
    participant Ctrl as CartController (Controller)
    participant Model as CartItem & Product (Model)
    participant Backend as Django API View (Backend Controller)
    participant DB as Postgres/SQLite (Backend Model)

    Merchant->>View: Taps "Add to Cart" or scans barcode
    View->>Ctrl: CartController.instance.add(product)
    Ctrl->>Model: Validates stock availability against Product.stock
    Model-->>Ctrl: Returns validated CartItem
    Ctrl-->>View: notifyListeners() (triggers reactive widget redraw)
    View-->>Merchant: Updates cart badge & running subtotal

    Merchant->>View: Taps "Confirm Cash Checkout"
    View->>Ctrl: CartController.checkout() / SalesController.recordSale()
    Ctrl->>Model: Appends Sale record to local storage / Drift
    Ctrl->>Backend: POST /api/v1/sales/
    Backend->>DB: Atomically deducts stock & inserts transaction
    DB-->>Backend: Confirmed row ID & timestamp
    Backend-->>Ctrl: HTTP 201 Created (SaleSerializer)
    Ctrl-->>View: notifyListeners() -> Clears cart & triggers receipt modal
    View-->>Merchant: Displays digital receipt dialog
```

---

## 5. Architectural Quality Guarantees

1. **Strict Separation of Concerns**: Views do not make raw SQL queries or execute untracked HTTP requests; all mutations flow through the respective Controllers.
2. **First-Class MVC Aliases**: The Flutter codebases expose dedicated `lib/controllers/` modules, allowing seamless integration with traditional MVC naming conventions while maintaining full compatibility with Flutter `Provider` and `ChangeNotifier` state architectures.
3. **Decoupled Testing**: Controllers and Models can be tested independently of Flutter widget rendering lifecycles and backend web servers.
