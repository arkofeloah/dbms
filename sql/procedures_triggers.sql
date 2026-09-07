-- ============================================================
-- Food Waste Redistribution Network
-- File 3: procedures_triggers.sql
-- Description: Trigger + Stored Procedures
-- MySQL 8.0
-- Run AFTER sample_data.sql
-- ============================================================

USE food_waste_db;

-- -------------------------------------------------------
-- Change DELIMITER so MySQL doesn't split compound bodies
-- -------------------------------------------------------
DELIMITER $$

-- ===========================================================
-- TRIGGER: trg_after_claim_insert
-- Fires AFTER INSERT on Claims.
-- Updates FoodListings.status → 'claimed' ONLY IF the listing
-- is currently 'available' AND has not yet expired.
-- This protects against accidentally overwriting 'expired'.
-- ===========================================================
CREATE TRIGGER trg_after_claim_insert
AFTER INSERT ON Claims
FOR EACH ROW
BEGIN
    UPDATE FoodListings
    SET    status = 'claimed'
    WHERE  listing_id      = NEW.listing_id
      AND  status          = 'available'        -- never overwrite expired/already-claimed
      AND  expiry_datetime > NOW();             -- confirm listing is still fresh
END$$


-- ===========================================================
-- STORED PROCEDURE: ClaimListing
-- Safely claims a food listing for a given NGO.
--
-- Flow:
--   1. Validate ngo_id exists in NGOs table.
--   2. SELECT ... FOR UPDATE to lock the listing row
--      (prevents two NGOs claiming the same listing).
--   3. Validate listing exists, is 'available', and not expired.
--   4. INSERT into Claims — trigger fires to update FoodListings.
--   5. Full transaction with EXIT HANDLER for rollback.
--
-- NOTE: Pickup scheduling is a separate operation; this
--       procedure only creates the claim record.
-- ===========================================================
CREATE PROCEDURE ClaimListing(
    IN p_listing_id INT,
    IN p_ngo_id     INT
)
BEGIN
    -- Local variables
    DECLARE v_ngo_count     INT DEFAULT 0;
    DECLARE v_listing_count INT DEFAULT 0;
    DECLARE v_status        VARCHAR(20);
    DECLARE v_expiry        DATETIME;

    -- Exit handler: rolls back and re-signals on any SQL exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- ── Step 1: Validate that the NGO exists ──────────────────
    SELECT COUNT(*) INTO v_ngo_count
    FROM   NGOs
    WHERE  ngo_id = p_ngo_id;

    IF v_ngo_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ClaimListing Error: NGO not found.';
    END IF;

    -- ── Step 2: Lock the listing row to prevent race conditions ─
    --    SELECT ... FOR UPDATE acquires an exclusive row lock.
    --    Any concurrent transaction trying to claim the same
    --    listing will block here until this transaction commits.
    SELECT status, expiry_datetime
    INTO   v_status, v_expiry
    FROM   FoodListings
    WHERE  listing_id = p_listing_id
    FOR UPDATE;

    -- ── Step 3a: Validate listing exists ─────────────────────
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ClaimListing Error: Food listing not found.';
    END IF;

    -- ── Step 3b: Validate listing is still available ──────────
    IF v_status <> 'available' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ClaimListing Error: Food listing is not available (already claimed or expired).';
    END IF;

    -- ── Step 3c: Validate listing has not expired ─────────────
    IF v_expiry <= NOW() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ClaimListing Error: Food listing has expired and cannot be claimed.';
    END IF;

    -- ── Step 4: Insert the claim ──────────────────────────────
    --    The AFTER INSERT trigger (trg_after_claim_insert) will
    --    automatically update FoodListings.status → 'claimed'.
    INSERT INTO Claims (listing_id, ngo_id, claimed_at, status)
    VALUES (p_listing_id, p_ngo_id, NOW(), 'pending');

    COMMIT;
END$$


-- ===========================================================
-- STORED PROCEDURE: GetAvailableListings
-- Returns all food listings that are currently available
-- and have not yet passed their expiry time.
-- Uses the composite index (status, expiry_datetime).
-- ===========================================================
CREATE PROCEDURE GetAvailableListings()
BEGIN
    SELECT
        fl.listing_id,
        d.org_name          AS donor_name,
        fl.food_type,
        fl.quantity,
        fl.posted_at,
        fl.expiry_datetime,
        TIMESTAMPDIFF(MINUTE, NOW(), fl.expiry_datetime) AS minutes_until_expiry
    FROM  FoodListings fl
    JOIN  Donors d ON fl.donor_id = d.donor_id
    WHERE fl.status         = 'available'
      AND fl.expiry_datetime > NOW()
    ORDER BY fl.expiry_datetime ASC;   -- soonest-to-expire first
END$$

DELIMITER ;
