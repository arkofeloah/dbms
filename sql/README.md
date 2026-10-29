# SQL Scripts & Database Documentation

This folder contains all the SQL definitions, seed data, stored procedures, triggers, and analytics queries for the **Food Waste Redistribution Network** (`food_waste_db`).

---

## 📁 File Directory

| File | Type | Target Environment | Purpose |
| :--- | :--- | :--- | :--- |
| [`food_network_schema.sql`](file:///c:/Users/Maranathasoul/Documents/dbms/sql/food_network_schema.sql) | DDL | Local MySQL 8.0 | Creates `food_waste_db` and all 6 core tables with foreign keys and indexes. |
| [`sample_data.sql`](file:///c:/Users/Maranathasoul/Documents/dbms/sql/sample_data.sql) | DML | Local MySQL 8.0 | Seeds realistic demo users, donors, NGOs, food listings, claims, and pickups. |
| [`procedures_triggers.sql`](file:///c:/Users/Maranathasoul/Documents/dbms/sql/procedures_triggers.sql) | Procedural | Local MySQL 8.0 | Defines `ClaimListing`, `GetAvailableListings`, and trigger `trg_after_claim_insert`. |
| [`analytics_queries.sql`](file:///c:/Users/Maranathasoul/Documents/dbms/sql/analytics_queries.sql) | DQL | Local MySQL 8.0 | Contains queries Q1 through Q6 used by the Admin Analytics Dashboard. |
| `*_freedb.sql` | All | Cloud / FreeDB / Aiven | Cloud-compatible variants that omit `CREATE DATABASE` / `USE` statements. |

---

## 🔄 Execution Order (For Fresh Database Setup)

When initializing the database on a new computer or server, execute the files in the following exact sequence:

```bash
# 1. Create database and core tables
mysql -u root -p < sql/food_network_schema.sql

# 2. Insert demo seed records
mysql -u root -p food_waste_db < sql/sample_data.sql

# 3. Create stored procedures and triggers
mysql -u root -p food_waste_db < sql/procedures_triggers.sql
```

*(Alternatively, run `scripts\restore_db.bat` on Windows and select Option 1).*

---

## 🗄️ Relational Schema Breakdown

### 1. `Users`
- `user_id`: INT AUTO_INCREMENT PRIMARY KEY
- `name`: VARCHAR(100) NOT NULL
- `email`: VARCHAR(100) NOT NULL UNIQUE (`uq_users_email`)
- `password_hash`: VARCHAR(255) NOT NULL (bcrypt or Werkzeug scrypt/pbkdf2 hash)
- `role`: ENUM('donor', 'ngo', 'admin') NOT NULL
- `phone`: VARCHAR(15) NULL

### 2. `Donors`
- `donor_id`: INT AUTO_INCREMENT PRIMARY KEY
- `user_id`: INT NOT NULL UNIQUE (`uq_donors_user_id`), FK -> `Users(user_id)`
- `org_name`: VARCHAR(100) NOT NULL
- `address`: VARCHAR(200) NOT NULL
- `donor_type`: ENUM('restaurant', 'store', 'event') NOT NULL

### 3. `NGOs`
- `ngo_id`: INT AUTO_INCREMENT PRIMARY KEY
- `user_id`: INT NOT NULL UNIQUE (`uq_ngos_user_id`), FK -> `Users(user_id)`
- `org_name`: VARCHAR(100) NOT NULL
- `address`: VARCHAR(200) NOT NULL
- `capacity`: INT NOT NULL (Maximum kg of food handled daily)

### 4. `FoodListings`
- `listing_id`: INT AUTO_INCREMENT PRIMARY KEY
- `donor_id`: INT NOT NULL, FK -> `Donors(donor_id)`
- `food_type`: VARCHAR(100) NOT NULL
- `quantity`: DECIMAL(6,2) NOT NULL (in kg)
- `posted_at`: DATETIME NOT NULL
- `expiry_datetime`: DATETIME NOT NULL
- `status`: ENUM('available', 'claimed', 'expired') DEFAULT 'available'
- **Index**: `idx_foodlistings_status_expiry` on `(status, expiry_datetime)` for fast queries.

### 5. `Claims`
- `claim_id`: INT AUTO_INCREMENT PRIMARY KEY
- `listing_id`: INT NOT NULL UNIQUE (`uq_claims_listing_id`), FK -> `FoodListings(listing_id)`
- `ngo_id`: INT NOT NULL, FK -> `NGOs(ngo_id)`
- `claimed_at`: DATETIME NOT NULL
- `status`: ENUM('pending', 'confirmed') DEFAULT 'pending'

### 6. `Pickups`
- `pickup_id`: INT AUTO_INCREMENT PRIMARY KEY
- `claim_id`: INT NOT NULL UNIQUE (`uq_pickups_claim_id`), FK -> `Claims(claim_id)`
- `scheduled_time`: DATETIME NOT NULL
- `actual_time`: DATETIME NULL
- `status`: ENUM('scheduled', 'completed', 'missed') DEFAULT 'scheduled'

---

## ⚡ Stored Procedures & Triggers

### Trigger: `trg_after_claim_insert`
- **Fires**: AFTER INSERT ON `Claims`
- **Action**: Automatically updates `FoodListings.status = 'claimed'` if and only if the listing is currently `'available'` and not yet expired (`expiry_datetime > NOW()`).

### Stored Procedure: `ClaimListing(p_listing_id INT, p_ngo_id INT)`
- **Purpose**: Concurrency-safe listing claim.
- **Mechanism**:
  1. Validates `p_ngo_id` exists in `NGOs`.
  2. Acquires an exclusive row lock (`SELECT ... FOR UPDATE`) on the listing in `FoodListings`.
  3. Verifies listing exists, status is `'available'`, and expiry has not passed.
  4. Inserts into `Claims` inside a transaction.
  5. Includes `EXIT HANDLER FOR SQLEXCEPTION` with automatic `ROLLBACK` and `RESIGNAL`.

### Stored Procedure: `GetAvailableListings()`
- **Purpose**: Fast, sorted feed of claimable food.
- **Mechanism**: Filters `status = 'available'` AND `expiry_datetime > NOW()`, ordered by `expiry_datetime ASC` (soonest to expire first), computing remaining minutes until expiration.

---

## 📊 Analytics Queries (Admin Dashboard)

1. **Q1 — Donations per Donor**: Aggregates total food quantity (kg) and total listings posted per donor.
2. **Q2 — Most Active NGOs**: Ranks NGOs by total claims made, breakdown of confirmed vs. pending.
3. **Q3 — Expired & Unclaimed**: Pinpoints surplus listings that expired before any NGO claimed them.
4. **Q4 — Average Time-to-Claim**: Calculates average, minimum, and maximum elapsed minutes from posting to claim.
5. **Q5 — Currently Available Listings**: Real-time snapshot of live food listings ready for redistribution.
6. **Q6 — Logistics Completion Rate**: Measures pickup efficiency (% of pickups marked `completed` vs. `missed` vs. `scheduled`).
