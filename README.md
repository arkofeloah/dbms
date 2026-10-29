# 🍲 Food Waste Redistribution Network (Zero Waste)

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.1%2B-green.svg)](https://flask.palletsprojects.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-orange.svg)](https://www.mysql.com/)
[![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3-purple.svg)](https://getbootstrap.com/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

A full-stack database-driven web application designed to eliminate urban food waste by connecting commercial food donors (restaurants, bakeries, supermarkets, event organizers) with non-profit humanitarian organizations (NGOs, shelters, community kitchens) in real time.

Built as an advanced Database Management System (DBMS) implementation featuring **ACID-compliant transactions**, **row-level locking concurrency controls**, **database triggers**, **stored procedures**, and **analytical KPI dashboards**.

---

## 📑 Table of Contents

- [Project Overview & Problem Statement](#-project-overview--problem-statement)
- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Technology Stack](#-technology-stack)
- [Database Architecture & Data Model](#-database-architecture--data-model)
  - [Entity-Relationship Diagram](#entity-relationship-diagram)
  - [Table Specifications](#table-specifications)
  - [Stored Procedures & Triggers](#stored-procedures--triggers)
  - [Analytics Queries (Admin Dashboard)](#analytics-queries-admin-dashboard)
- [Project Directory Structure](#-project-directory-structure)
- [Getting Started & Installation](#-getting-started--installation)
  - [Prerequisites](#prerequisites)
  - [Quick Start on Windows (Automated)](#quick-start-on-windows-automated)
  - [Manual Setup (Step-by-Step)](#manual-setup-step-by-step)
- [Environment Configuration (.env)](#-environment-configuration-env)
- [Pre-Seeded Demo Accounts](#-pre-seeded-demo-accounts)
- [Application Route Map](#-application-route-map)
- [Testing & Quality Assurance](#-testing--quality-assurance)
- [Database Backup & Recovery](#-database-backup--recovery)
- [Troubleshooting & FAQ](#-troubleshooting--faq)
- [Production Deployment](#-production-deployment)

---

## 🎯 Project Overview & Problem Statement

Every day, commercial food businesses discard tons of safe, edible surplus food due to overproduction or upcoming freshness deadlines. Simultaneously, local relief organizations and shelters struggle to source nutritious meals for vulnerable populations. 

**Food Waste Redistribution Network (FoodNet)** bridges this logistical divide:
1. Donors post surplus food listings with exact quantities and perishable expiration deadlines.
2. NGOs immediately view real-time feeds of available food ordered by earliest expiration.
3. NGOs claim items through atomic, row-locked database procedures that prevent double-booking.
4. Logistics workflows schedule pickups, track completion, and record delivery timestamps.
5. Administrative dashboards compute analytical insights to measure network impact and operational efficiency.

---

## ✨ Key Features

### 🏢 1. Donor Portal
- **Dashboard**: Track all historical and active food listings with status tags (`available`, `claimed`, `expired`).
- **Post Surplus Food**: Quick submission form capturing food type, quantity in kilograms, and perishable expiration datetime.
- **Auto-Sync**: Immediate feed updates once an item is claimed by an NGO.

### 🤝 2. NGO Portal
- **Live Food Feed**: Browse available food listings sorted by impending expiration (`GetAvailableListings` stored procedure).
- **Concurrency-Safe Claiming**: Claim donations using atomic transactions with row-level locks (`ClaimListing` stored procedure).
- **My Claims Logistics**: View claimed items, track pickup deadlines, schedule collection date/time, and mark collections as `completed` or `missed`.

### 📊 3. Admin Analytics Dashboard
Live KPI metrics and comprehensive analytics queries:
- **KPI Metrics**: Average time-to-claim (minutes), overall pickup completion rate (%), total claims count, and total expired/unclaimed listings.
- **Q1 — Donations per Donor**: Aggregates total food quantity (kg) and total listings posted per donor.
- **Q2 — Most Active NGOs**: Ranks NGOs by total claims made (confirmed vs. pending).
- **Q3 — Expired & Unclaimed**: Audits food items that passed their expiration date without being claimed.
- **Q4 — Average Time-to-Claim**: Measures responsiveness across the network.
- **Q5 — Live Available Listings**: Displays current active inventory with dynamic countdowns.
- **Q6 — Logistics Completion Rate**: Tracks scheduled vs. completed vs. missed collections.

### 🛡️ 4. Concurrency & Security
- **Row-Locking (`FOR UPDATE`)**: Prevents race conditions when multiple NGOs attempt to claim the same food listing at the same millisecond.
- **Trigger Automation**: `trg_after_claim_insert` atomically updates listing status upon claim creation.
- **Query-Time Expiration Sweep**: Automatically marks scheduled pickups as `missed` if food reaches its expiration time before pickup.
- **Role-Based Access Control**: Strict route decorators (`@login_required`, `@role_required`) enforce separation of privileges.
- **SQL Injection Defense**: 100% parameterized queries throughout all database calls.
- **Password Security**: Passwords hashed using industry-standard `bcrypt` and `Werkzeug` cryptographic algorithms.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Client Browser                        │
│             (HTML5 / Bootstrap 5.3 / Responsive UI)         │
└──────────────────────────────▲──────────────────────────────┘
                               │ HTTP Requests / Form Posts
┌──────────────────────────────▼──────────────────────────────┐
│                    Flask Web Application                    │
│                 (backend/app.py - Python 3)                 │
│  ├── Session Authentication & Role Authorization Decorators  │
│  ├── Route Controllers (Donor, NGO, Admin, Auth)             │
│  └── Jinja2 Template Rendering Engine                       │
└──────────────────────────────▲──────────────────────────────┘
                               │ DB-API (mysql-connector-python)
┌──────────────────────────────▼──────────────────────────────┐
│                      MySQL 8.0 Server                       │
│                     (food_waste_db)                         │
│  ├── 6 Relational Tables with Foreign Key Constraints       │
│  ├── Composite Index (status, expiry_datetime)               │
│  ├── Atomic Stored Procedures (ClaimListing, GetAvailable)   │
│  └── AFTER INSERT Trigger (trg_after_claim_insert)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Technology Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Backend** | Python 3.10+ | Core server language |
| **Framework** | Flask 3.1.3 | Lightweight, modular WSGI web framework |
| **Database** | MySQL 8.0 | ACID-compliant relational database management system |
| **Driver** | mysql-connector-python | Pure-Python MySQL client driver |
| **Frontend** | Jinja2, HTML5, CSS3 | Server-side templated responsive UI |
| **Styling** | Bootstrap 5.3.3 & Icons | Responsive grid system, badges, and icon set |
| **Security** | Werkzeug & bcrypt | Secure password hashing (`scrypt`/`pbkdf2`/`bcrypt`) |
| **Testing** | Standard `urllib` & HTTP Cookie Jar | Automated end-to-end integration test suite |

---

## 🗄️ Database Architecture & Data Model

### Entity-Relationship Diagram

```
 +--------------------+       1:1       +--------------------+
 |       Users        | <-------------- |       Donors       |
 |--------------------|                 |--------------------|
 | PK user_id         |                 | PK donor_id        |
 |    email (UQ)      |                 | FK user_id (UQ)    |
 |    password_hash   |                 |    org_name        |
 |    role            |                 |    donor_type      |
 |    name, phone     |                 +---------+----------+
 +---------+----------+                           |
           |                                      | 1:N
           | 1:1                                  v
           |                            +--------------------+
           v                            |    FoodListings    |
 +--------------------+                 |--------------------|
 |        NGOs        |                 | PK listing_id      |
 |--------------------|                 | FK donor_id        |
 | PK ngo_id          |                 |    food_type       |
 | FK user_id (UQ)    |                 |    quantity (kg)   |
 |    org_name        |                 |    posted_at       |
 |    capacity        |                 |    expiry_datetime |
 +---------+----------+                 |    status          |
           |                            +---------+----------+
           | 1:N                                  |
           |                                      | 1:1 (UQ)
           v                                      v
 +--------------------+       1:1       +--------------------+
 |       Claims       | --------------> |      Pickups       |
 |--------------------|                 |--------------------|
 | PK claim_id        |                 | PK pickup_id       |
 | FK listing_id (UQ) |                 | FK claim_id (UQ)   |
 | FK ngo_id          |                 |    scheduled_time  |
 |    claimed_at      |                 |    actual_time     |
 |    status          |                 |    status          |
 +--------------------+                 +--------------------+
```

### Table Specifications

1. **`Users`**: Central authentication identity table.
   - `user_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `name`: VARCHAR(100) NOT NULL
   - `email`: VARCHAR(100) NOT NULL UNIQUE
   - `password_hash`: VARCHAR(255) NOT NULL
   - `role`: ENUM('donor', 'ngo', 'admin') NOT NULL
   - `phone`: VARCHAR(15) NULL

2. **`Donors`**: Profile details for food-donating businesses.
   - `donor_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `user_id`: INT NOT NULL UNIQUE (FK -> `Users.user_id`)
   - `org_name`: VARCHAR(100) NOT NULL
   - `address`: VARCHAR(200) NOT NULL
   - `donor_type`: ENUM('restaurant', 'store', 'event') NOT NULL

3. **`NGOs`**: Profile details for relief organizations.
   - `ngo_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `user_id`: INT NOT NULL UNIQUE (FK -> `Users.user_id`)
   - `org_name`: VARCHAR(100) NOT NULL
   - `address`: VARCHAR(200) NOT NULL
   - `capacity`: INT NOT NULL (Max kilograms of food handled daily)

4. **`FoodListings`**: Surplus food items posted by donors.
   - `listing_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `donor_id`: INT NOT NULL (FK -> `Donors.donor_id`)
   - `food_type`: VARCHAR(100) NOT NULL
   - `quantity`: DECIMAL(6,2) NOT NULL (in kilograms)
   - `posted_at`: DATETIME NOT NULL
   - `expiry_datetime`: DATETIME NOT NULL
   - `status`: ENUM('available', 'claimed', 'expired') DEFAULT 'available'
   - **Composite Index**: `idx_foodlistings_status_expiry` on `(status, expiry_datetime)`

5. **`Claims`**: Records claims placed by NGOs on food listings.
   - `claim_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `listing_id`: INT NOT NULL UNIQUE (FK -> `FoodListings.listing_id`)
   - `ngo_id`: INT NOT NULL (FK -> `NGOs.ngo_id`)
   - `claimed_at`: DATETIME NOT NULL
   - `status`: ENUM('pending', 'confirmed') DEFAULT 'pending'

6. **`Pickups`**: Logistics tracking for claimed donations.
   - `pickup_id`: INT AUTO_INCREMENT PRIMARY KEY
   - `claim_id`: INT NOT NULL UNIQUE (FK -> `Claims.claim_id`)
   - `scheduled_time`: DATETIME NOT NULL
   - `actual_time`: DATETIME NULL
   - `status`: ENUM('scheduled', 'completed', 'missed') DEFAULT 'scheduled'

### Stored Procedures & Triggers

- **Trigger `trg_after_claim_insert`**:
  Fires immediately after an insert on `Claims`. Automatically updates the associated `FoodListings.status = 'claimed'` while verifying that the item is still available and not expired.
- **Stored Procedure `ClaimListing(IN p_listing_id INT, IN p_ngo_id INT)`**:
  Executes an atomic transaction with `SELECT ... FOR UPDATE` row locking. Rejects double-claims, expired listings, or invalid NGOs, and rolls back cleanly upon any SQL exception.
- **Stored Procedure `GetAvailableListings()`**:
  Retrieves active available food listings ordered soonest-to-expire first, calculating real-time minutes remaining until expiration.

---

## 📁 Project Directory Structure

```
dbms/
├── .env.example                       # Root template for environment settings
├── .gitignore                          # Git exclusion list (protects .env and backups)
├── README.md                           # Master project documentation
├── requirements.txt                    # Top-level Python dependency specification
├── run.bat                             # One-click Windows application launcher
├── setup.bat                           # One-click Windows dependency & venv installer
│
├── backend/
│   ├── .env.example                   # Backend environment template
│   ├── app.py                         # Main Flask application and routing logic
│   ├── db.py                          # MySQL connection helper and pool configuration
│   ├── Procfile                       # Production WSGI entry point for Gunicorn
│   ├── requirements.txt               # Backend Python package list
│   ├── test_e2e.py                    # Automated end-to-end integration test suite
│   │
│   ├── static/
│   │   └── style.css                  # Custom styling, color badges, responsive tables
│   │
│   └── templates/                     # Jinja2 HTML templates
│       ├── base.html                  # Global layout, navigation bar, flash messages
│       ├── login.html                 # Login page with demo account quick-fill buttons
│       ├── register.html              # Dynamic registration for Donors and NGOs
│       ├── donor_dashboard.html       # Donor donation tracking dashboard
│       ├── post_listing.html          # New surplus food listing submission form
│       ├── ngo_dashboard.html         # Live available food feed with claim buttons
│       ├── ngo_my_claims.html         # NGO claims and pickup management dashboard
│       ├── schedule_pickup.html       # Pickup logistics scheduling form
│       └── admin_dashboard.html       # 6 analytical queries & KPI cards
│
├── scripts/
│   ├── backup_db.bat                  # Safe automated mysqldump script
│   └── restore_db.bat                 # Safe database restore and schema initializer
│
└── sql/
    ├── README.md                      # Detailed SQL scripts documentation
    ├── food_network_schema.sql        # Core DDL schema (Tables, constraints, indexes)
    ├── sample_data.sql                # Seed data for demo users, listings, claims
    ├── procedures_triggers.sql        # Stored procedures and trigger definitions
    ├── analytics_queries.sql          # 6 SQL reporting queries (Q1 - Q6)
    ├── food_network_schema_freedb.sql # Cloud-compatible schema (omits CREATE/USE DB)
    ├── sample_data_freedb.sql         # Cloud-compatible seed data
    ├── procedures_triggers_freedb.sql # Cloud-compatible procedures & triggers
    └── analytics_queries_freedb.sql   # Cloud-compatible analytics queries
```

---

## 🚀 Getting Started & Installation

### Prerequisites

1. **Python 3.10+**: Download from [python.org](https://www.python.org/downloads/). During installation on Windows, **check "Add python.exe to PATH"**.
2. **MySQL Server 8.0**: Download [MySQL Community Server](https://dev.mysql.com/downloads/installer/). Ensure the MySQL service (`MySQL80`) is running.

---

### Quick Start on Windows (Automated)

The project includes batch scripts that handle setup, dependency installation, and launching automatically.

1. **Run Setup**:
   Double-click `setup.bat` (or execute in PowerShell):
   ```cmd
   setup.bat
   ```
   This script creates the `venv` virtual environment, installs dependencies, and creates `backend\.env` from `.env.example`.

2. **Configure Database Password**:
   Open `backend\.env` in Notepad and set your local MySQL root password:
   ```env
   DB_PASSWORD=your_mysql_password
   ```

3. **Initialize Database (If setting up fresh)**:
   Double-click `scripts\restore_db.bat` and select `[1]` to initialize the schema, seed data, and stored procedures.

4. **Launch Application**:
   Double-click `run.bat`:
   ```cmd
   run.bat
   ```
   Open your browser at **[http://127.0.0.1:5000](http://127.0.0.1:5000)**.

---

### Manual Setup (Step-by-Step)

If you prefer to configure everything manually in your terminal:

#### 1. Clone the Repository
```bash
git clone https://github.com/arkofeloah/dbms.git
cd dbms
```

#### 2. Create and Activate Virtual Environment
```bash
# Windows
python -m venv venv
call venv\Scripts\activate

# macOS / Linux
python3 -m venv venv
source venv/bin/activate
```

#### 3. Install Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

#### 4. Configure Environment Variables
Copy `backend/.env.example` to `backend/.env`:
```bash
# Windows
copy backend\.env.example backend\.env

# macOS / Linux
cp backend/.env.example backend/.env
```
Edit `backend/.env` with your MySQL credentials:
```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_actual_password
DB_NAME=food_waste_db
DB_SSL_DISABLED=true
SECRET_KEY=dev-secret-key-food-waste-2026
```

#### 5. Initialize the MySQL Database
Execute the SQL files in order:
```bash
# 1. Create database and core tables
mysql -u root -p < sql/food_network_schema.sql

# 2. Insert sample demo data
mysql -u root -p food_waste_db < sql/sample_data.sql

# 3. Create stored procedures and triggers
mysql -u root -p food_waste_db < sql/procedures_triggers.sql
```

#### 6. Run the Flask Server
```bash
python backend/app.py
```
Open **[http://127.0.0.1:5000](http://127.0.0.1:5000)** in your web browser.

---

## 🔑 Pre-Seeded Demo Accounts

The database comes pre-seeded with realistic accounts for each user role. You can log in using these credentials or click the **Demo Accounts** buttons directly on the `/login` page:

| Role | Organization / Name | Email | Password |
| :--- | :--- | :--- | :--- |
| 🛡️ **Admin** | FoodNet Administration | `admin@foodwaste.network` | `Password@123` |
| 🤝 **NGO** | Sahara Relief | `contact@sahararelief.ngo` | `Password@123` |
| 🤝 **NGO** | Hope Foundation | `hope@hopefoundation.org` | `Password@123` |
| 🤝 **NGO** | Green Plate NGO | `info@greenplate.org` | `Password@123` |
| 🏢 **Donor** | Ravi's Kitchen (Restaurant) | `ravi.sharma@gmail.com` | `Password@123` |
| 🏢 **Donor** | Meena's Bakery (Store) | `meena.bakery@outlook.com` | `Password@123` |
| 🏢 **Donor** | City Mart Supermarket | `citymart@citymart.in` | `Password@123` |
| 🏢 **Donor** | Sunrise Event Managers | `sunrise.events@events.com` | `Password@123` |

---

## 🗺️ Application Route Map

| Method | Endpoint | Access Role | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/` | Public | Root redirector: sends logged-in users to their respective role dashboard, or guests to `/login`. |
| `GET`, `POST` | `/login` | Public | Session authentication; verifies passwords against bcrypt/Werkzeug hashes. |
| `GET`, `POST` | `/register` | Public | User self-registration as Donor or NGO (Admin registration blocked for security). |
| `GET` | `/logout` | Authenticated | Clears user session and redirects to `/login`. |
| `GET` | `/donor/dashboard` | `donor` | View donor's own food listings and claim statuses. |
| `GET`, `POST` | `/donor/post-listing` | `donor` | Post a new surplus food listing (food type, quantity, expiry). |
| `GET` | `/ngo/dashboard` | `ngo` | Browse available live listings from `GetAvailableListings()` stored procedure. |
| `POST` | `/ngo/claim/<listing_id>` | `ngo` | Safely claim a food listing using atomic `ClaimListing` stored procedure. |
| `GET` | `/ngo/my-claims` | `ngo` | View NGO's claimed donations, overdue statuses, and pickup timelines. |
| `GET`, `POST` | `/ngo/schedule-pickup/<claim_id>` | `ngo` | Schedule pickup datetime for a confirmed claim (ownership verified). |
| `POST` | `/ngo/complete-pickup/<pickup_id>` | `ngo` | Mark pickup as `completed` (sets actual collection timestamp) or `missed`. |
| `GET` | `/admin/dashboard` | `admin` | View all 6 analytical queries and live system KPI widgets. |

---

## 🧪 Testing & Quality Assurance

The application includes an end-to-end integration test suite in [`backend/test_e2e.py`](file:///c:/Users/Maranathasoul/Documents/dbms/backend/test_e2e.py).

### Running Automated Tests

Make sure the Flask server is running in one terminal, then open another terminal:
```bash
# Windows
venv\Scripts\python.exe backend\test_e2e.py

# macOS / Linux
venv/bin/python backend/test_e2e.py
```

### What the Automated Test Verifies:
1. **Donor Registration**: Registers a unique donor account via `POST /register` and confirms proper password hashing and redirect.
2. **Donor Posting**: Logs in as the new donor and posts a surplus food listing (`25.50 kg`).
3. **NGO Claim & Logistics**: Logs in as an NGO (`contact@sahararelief.ngo`), verifies visibility of the new listing, claims it via stored procedure, and schedules a pickup datetime.
4. **Admin Analytics Verification**: Logs in as Admin (`admin@foodwaste.network`) and verifies that all 6 reporting query tables and KPI metrics load accurately.

---

## 💾 Database Backup & Recovery

### Automated Backup (Windows)
Run `scripts\backup_db.bat`:
```cmd
scripts\backup_db.bat
```
- Creates a timestamped `.sql` dump inside `backups\` (e.g., `backups\food_waste_db_backup_2026-10-29_19-45.sql`).
- Includes all table schemas, data, routines, and triggers.
- The `backups\` folder is ignored by `.gitignore` to prevent confidential database dumps from being pushed to Git.

### Automated Restore (Windows)
Run `scripts\restore_db.bat`:
```cmd
scripts\restore_db.bat
```
- **Option 1**: Re-initializes a fresh database from the source SQL scripts.
- **Option 2**: Restores a previously created backup `.sql` file.

---

## ❓ Troubleshooting & FAQ

### 1. `Can't connect to MySQL server on '127.0.0.1:3306'`
- **Cause**: The MySQL service is not running.
- **Fix**: Open PowerShell as Administrator and run:
  ```powershell
  Start-Service MySQL80
  ```
  *(Or check Services in Windows and start `MySQL80`).*

### 2. `Access denied for user 'root'@'localhost'`
- **Cause**: The password in `backend\.env` does not match your MySQL server password.
- **Fix**: Open `backend\.env` and verify the `DB_PASSWORD` entry.

### 3. `Address already in use (Port 5000)`
- **Cause**: Another process or background instance of Flask is running.
- **Fix**: In PowerShell, find and kill the process:
  ```powershell
  Get-Process -Name python | Stop-Process -Force
  ```

---

## 🌐 Production Deployment

The project includes [`backend/Procfile`](file:///c:/Users/Maranathasoul/Documents/dbms/backend/Procfile) configured for deployment to platforms like Render, Railway, or Heroku:

```
web: gunicorn --chdir backend app:app
```

### Production Checklist:
1. Set `SECRET_KEY` in your hosting environment variables to a cryptographically secure random string (`python -c "import secrets; print(secrets.token_hex(32))"`).
2. Set `DB_SSL_DISABLED=false` and provide SSL CA certificates if using a managed cloud database (Aiven, PlanetScale, AWS RDS).
3. Ensure debug mode is disabled (`debug=False`).

---

## 📄 License

This project is licensed under the MIT License — see the repository for details.
