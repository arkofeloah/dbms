-- ============================================================
-- Food Waste Redistribution Network
-- File: sample_data_freedb.sql
-- Description: Realistic seed data for all 6 tables (FreeDB compatible)
-- MySQL 8.0
-- Run AFTER food_network_schema_freedb.sql
-- ============================================================

-- -------------------------------------------------------
-- Users (8 rows: 4 donors, 3 ngos, 1 admin)
-- Passwords are bcrypt hashes of 'Password@123'
-- -------------------------------------------------------
INSERT INTO Users (name, email, password_hash, role, phone) VALUES
('Ravi Sharma',      'ravi.sharma@gmail.com',       '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'donor', '9876543210'),
('Meena Bakery',     'meena.bakery@outlook.com',    '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'donor', '9123456780'),
('City Mart Store',  'citymart@citymart.in',        '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'donor', '9988776655'),
('Sunrise Events',   'sunrise.events@events.com',   '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'donor', '8800112233'),
('Hope Foundation',  'hope@hopefoundation.org',     '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'ngo',   '7700223344'),
('Sahara Relief',    'contact@sahararelief.ngo',    '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'ngo',   '7711334455'),
('Green Plate NGO',  'info@greenplate.org',         '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'ngo',   '7722445566'),
('Admin User',       'admin@foodwaste.network',     '$2b$12$XZeiNBrkT7pPaRmp5Y22zOgcw4EwOqk.ULTtEcM0RfbGaZ1rMRcH.', 'admin', NULL);

-- -------------------------------------------------------
-- Donors (4 rows, linked to user_id 1–4)
-- -------------------------------------------------------
INSERT INTO Donors (user_id, org_name, address, donor_type) VALUES
(1, 'Ravi''s Kitchen',        '12, MG Road, Bengaluru, Karnataka 560001',             'restaurant'),
(2, 'Meena''s Bakery',        '45, Anna Salai, Chennai, Tamil Nadu 600002',           'store'),
(3, 'City Mart Supermarket',  '78, Linking Road, Mumbai, Maharashtra 400050',         'store'),
(4, 'Sunrise Event Managers', '22, Connaught Place, New Delhi, Delhi 110001',         'event');

-- -------------------------------------------------------
-- NGOs (3 rows, linked to user_id 5–7)
-- capacity = max kg of food the NGO can handle per day
-- -------------------------------------------------------
INSERT INTO NGOs (user_id, org_name, address, capacity) VALUES
(5, 'Hope Foundation',  '7, Gandhi Nagar, Hyderabad, Telangana 500001', 200),
(6, 'Sahara Relief',    '33, Park Street, Kolkata, West Bengal 700016', 350),
(7, 'Green Plate NGO',  '9, Residency Road, Bengaluru, Karnataka 560025', 150);

-- -------------------------------------------------------
-- FoodListings (10 rows across 4 donors)
-- Mix of available / claimed / expired statuses
-- expiry_datetime anchored relative to 2026-09-08 03:40 IST
-- -------------------------------------------------------
INSERT INTO FoodListings (donor_id, food_type, quantity, posted_at, expiry_datetime, status) VALUES
-- available (expiry in the future)
(1, 'Cooked Biryani',        45.00, '2026-09-08 01:00:00', '2026-09-08 10:00:00', 'available'),
(1, 'Vegetable Curry',       30.00, '2026-09-08 02:00:00', '2026-09-08 12:00:00', 'available'),
(2, 'Assorted Bread Loaves', 20.00, '2026-09-08 00:30:00', '2026-09-08 08:00:00', 'available'),
(3, 'Packaged Dairy Items',  15.50, '2026-09-07 22:00:00', '2026-09-09 06:00:00', 'available'),
-- claimed (expiry in the future, but already claimed)
(2, 'Pastries & Cakes',      12.00, '2026-09-07 20:00:00', '2026-09-08 09:00:00', 'claimed'),
(3, 'Canned Vegetables',     60.00, '2026-09-07 18:00:00', '2026-09-10 18:00:00', 'claimed'),
(4, 'Catering Rice Surplus', 80.00, '2026-09-07 16:00:00', '2026-09-08 06:00:00', 'claimed'),
-- expired (expiry in the past, never claimed)
(1, 'Leftover Naan Bread',   18.00, '2026-09-06 08:00:00', '2026-09-07 08:00:00', 'expired'),
(4, 'Mixed Salads',          10.00, '2026-09-05 10:00:00', '2026-09-06 14:00:00', 'expired'),
(3, 'Fruit Platters',        25.00, '2026-09-06 12:00:00', '2026-09-07 12:00:00', 'expired');

-- -------------------------------------------------------
-- Claims (5 rows, only against claimed listings: 5,6,7)
-- + two additional available listings claimed via procedure
-- We directly insert for listings 5,6,7 which are already
-- marked 'claimed' in FoodListings above.
-- Also claim listings 1 & 2 here (they'll be updated by
-- the trigger in procedures_triggers.sql once that is loaded).
-- For now we set them as 'pending' with correct ngo_ids.
-- -------------------------------------------------------
INSERT INTO Claims (listing_id, ngo_id, claimed_at, status) VALUES
(5, 1, '2026-09-07 21:00:00', 'confirmed'),   -- Pastries  → Hope Foundation
(6, 2, '2026-09-07 19:30:00', 'confirmed'),   -- Canned Veg → Sahara Relief
(7, 3, '2026-09-07 17:00:00', 'confirmed'),   -- Rice Surplus → Green Plate
(1, 2, '2026-09-08 03:00:00', 'pending'),     -- Biryani   → Sahara Relief
(2, 1, '2026-09-08 03:10:00', 'pending');     -- Veg Curry → Hope Foundation

-- Sync FoodListings status for listings 1 & 2 claimed above
UPDATE FoodListings SET status = 'claimed' WHERE listing_id IN (1, 2);

-- -------------------------------------------------------
-- Pickups (5 rows, one per claim)
-- Mix of scheduled / completed / missed
-- -------------------------------------------------------
INSERT INTO Pickups (claim_id, scheduled_time, actual_time, status) VALUES
(1, '2026-09-07 22:00:00', '2026-09-07 22:15:00', 'completed'),  -- Pastries pickup done
(2, '2026-09-07 21:00:00', '2026-09-07 21:05:00', 'completed'),  -- Canned Veg done
(3, '2026-09-07 18:30:00', NULL,                  'missed'),     -- Rice Surplus missed
(4, '2026-09-08 07:00:00', NULL,                  'scheduled'),  -- Biryani upcoming
(5, '2026-09-08 08:00:00', NULL,                  'scheduled');  -- Veg Curry upcoming
