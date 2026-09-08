-- ============================================================
-- Food Waste Redistribution Network
-- File: analytics_queries_freedb.sql
-- Description: 6 analytical queries for reporting & insights (FreeDB compatible)
-- MySQL 8.0
-- Run AFTER procedures_triggers_freedb.sql
-- ============================================================

-- -------------------------------------------------------
-- Query 1: Total Donations per Donor
-- Shows total quantity donated and number of listings
-- posted by each donor organisation.
-- -------------------------------------------------------
SELECT
    d.donor_id,
    d.org_name                         AS donor_name,
    d.donor_type,
    COUNT(fl.listing_id)               AS total_listings,
    COALESCE(SUM(fl.quantity), 0)      AS total_quantity_kg
FROM  Donors d
LEFT JOIN FoodListings fl ON fl.donor_id = d.donor_id
GROUP BY d.donor_id, d.org_name, d.donor_type
ORDER BY total_quantity_kg DESC;


-- -------------------------------------------------------
-- Query 2: Most Active NGOs (by claim count)
-- Ranks NGOs by how many claims they have made.
-- -------------------------------------------------------
SELECT
    n.ngo_id,
    n.org_name                         AS ngo_name,
    n.capacity                         AS capacity_kg,
    COUNT(c.claim_id)                  AS total_claims,
    SUM(CASE WHEN c.status = 'confirmed' THEN 1 ELSE 0 END) AS confirmed_claims,
    SUM(CASE WHEN c.status = 'pending'   THEN 1 ELSE 0 END) AS pending_claims
FROM  NGOs n
LEFT JOIN Claims c ON c.ngo_id = n.ngo_id
GROUP BY n.ngo_id, n.org_name, n.capacity
ORDER BY total_claims DESC;


-- -------------------------------------------------------
-- Query 3: Expired & Unclaimed Listings
-- Listings whose expiry_datetime has passed AND that were
-- never associated with any claim (wasted food).
-- -------------------------------------------------------
SELECT
    fl.listing_id,
    d.org_name                         AS donor_name,
    fl.food_type,
    fl.quantity,
    fl.posted_at,
    fl.expiry_datetime,
    TIMESTAMPDIFF(HOUR, fl.expiry_datetime, NOW()) AS hours_since_expired
FROM  FoodListings fl
JOIN  Donors d ON fl.donor_id = d.donor_id
WHERE fl.expiry_datetime < NOW()
  AND fl.listing_id NOT IN (
        SELECT listing_id FROM Claims
  )
ORDER BY fl.expiry_datetime DESC;


-- -------------------------------------------------------
-- Query 4: Average Time-to-Claim
-- Measures responsiveness: how quickly NGOs claim listings
-- after they are posted. Computed as claimed_at − posted_at.
-- -------------------------------------------------------
SELECT
    AVG(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS avg_minutes_to_claim,
    MIN(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS min_minutes_to_claim,
    MAX(TIMESTAMPDIFF(MINUTE, fl.posted_at, c.claimed_at)) AS max_minutes_to_claim,
    COUNT(*)                                                AS total_claims_analysed
FROM  Claims c
JOIN  FoodListings fl ON fl.listing_id = c.listing_id;


-- -------------------------------------------------------
-- Query 5: All Currently Available Listings
-- Listings that are still 'available' and not yet expired.
-- Mirrors the GetAvailableListings() stored procedure
-- as a plain query for reporting purposes.
-- -------------------------------------------------------
SELECT
    fl.listing_id,
    d.org_name                          AS donor_name,
    d.donor_type,
    fl.food_type,
    fl.quantity,
    fl.posted_at,
    fl.expiry_datetime,
    TIMESTAMPDIFF(MINUTE, NOW(), fl.expiry_datetime) AS minutes_until_expiry
FROM  FoodListings fl
JOIN  Donors d ON fl.donor_id = d.donor_id
WHERE fl.status          = 'available'
  AND fl.expiry_datetime  > NOW()
ORDER BY fl.expiry_datetime ASC;


-- -------------------------------------------------------
-- Query 6: Pickup Completion Rate
-- Percentage of pickups that were actually completed
-- vs. total pickups (completed + missed + scheduled).
-- -------------------------------------------------------
SELECT
    COUNT(*)                                                   AS total_pickups,
    SUM(CASE WHEN status = 'completed'  THEN 1 ELSE 0 END)    AS completed,
    SUM(CASE WHEN status = 'missed'     THEN 1 ELSE 0 END)    AS missed,
    SUM(CASE WHEN status = 'scheduled'  THEN 1 ELSE 0 END)    AS scheduled,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0),
        2
    )                                                          AS completion_rate_pct
FROM  Pickups;
