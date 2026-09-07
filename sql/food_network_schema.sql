-- ============================================================
-- Food Waste Redistribution Network
-- File 1: food_network_schema.sql
-- Description: Creates the database and all core tables
-- MySQL 8.0
-- ============================================================

DROP DATABASE IF EXISTS food_waste_db;
CREATE DATABASE food_waste_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE food_waste_db;

-- -------------------------------------------------------
-- Table: Users
-- Central identity table for all actors in the system
-- -------------------------------------------------------
CREATE TABLE Users (
    user_id       INT           NOT NULL AUTO_INCREMENT,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(100)  NOT NULL,
    password_hash VARCHAR(255)  NOT NULL,
    role          ENUM('donor','ngo','admin') NOT NULL,
    phone         VARCHAR(15)   NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- Table: Donors
-- Extended profile for users with role = 'donor'
-- -------------------------------------------------------
CREATE TABLE Donors (
    donor_id   INT          NOT NULL AUTO_INCREMENT,
    user_id    INT          NOT NULL,
    org_name   VARCHAR(100) NOT NULL,
    address    VARCHAR(200) NOT NULL,
    donor_type ENUM('restaurant','store','event') NOT NULL,
    PRIMARY KEY (donor_id),
    UNIQUE KEY uq_donors_user_id (user_id),
    CONSTRAINT fk_donors_user
        FOREIGN KEY (user_id) REFERENCES Users (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- Table: NGOs
-- Extended profile for users with role = 'ngo'
-- -------------------------------------------------------
CREATE TABLE NGOs (
    ngo_id   INT          NOT NULL AUTO_INCREMENT,
    user_id  INT          NOT NULL,
    org_name VARCHAR(100) NOT NULL,
    address  VARCHAR(200) NOT NULL,
    capacity INT          NOT NULL,
    PRIMARY KEY (ngo_id),
    UNIQUE KEY uq_ngos_user_id (user_id),
    CONSTRAINT fk_ngos_user
        FOREIGN KEY (user_id) REFERENCES Users (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- Table: FoodListings
-- Food items posted by donors for redistribution
-- Composite index on (status, expiry_datetime) supports
-- efficient filtering of available/non-expired listings
-- -------------------------------------------------------
CREATE TABLE FoodListings (
    listing_id       INT             NOT NULL AUTO_INCREMENT,
    donor_id         INT             NOT NULL,
    food_type        VARCHAR(100)    NOT NULL,
    quantity         DECIMAL(6,2)    NOT NULL,
    posted_at        DATETIME        NOT NULL,
    expiry_datetime  DATETIME        NOT NULL,
    status           ENUM('available','claimed','expired') NOT NULL DEFAULT 'available',
    PRIMARY KEY (listing_id),
    INDEX idx_foodlistings_status_expiry (status, expiry_datetime),
    CONSTRAINT fk_foodlistings_donor
        FOREIGN KEY (donor_id) REFERENCES Donors (donor_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- Table: Claims
-- Records an NGO claiming a specific food listing
-- listing_id is UNIQUE — one claim per listing
-- -------------------------------------------------------
CREATE TABLE Claims (
    claim_id   INT      NOT NULL AUTO_INCREMENT,
    listing_id INT      NOT NULL,
    ngo_id     INT      NOT NULL,
    claimed_at DATETIME NOT NULL,
    status     ENUM('pending','confirmed') NOT NULL DEFAULT 'pending',
    PRIMARY KEY (claim_id),
    UNIQUE KEY uq_claims_listing_id (listing_id),
    CONSTRAINT fk_claims_listing
        FOREIGN KEY (listing_id) REFERENCES FoodListings (listing_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_claims_ngo
        FOREIGN KEY (ngo_id) REFERENCES NGOs (ngo_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- Table: Pickups
-- Logistics record for each confirmed claim
-- claim_id is UNIQUE — one pickup per claim
-- -------------------------------------------------------
CREATE TABLE Pickups (
    pickup_id      INT      NOT NULL AUTO_INCREMENT,
    claim_id       INT      NOT NULL,
    scheduled_time DATETIME NOT NULL,
    actual_time    DATETIME NULL,
    status         ENUM('scheduled','completed','missed') NOT NULL DEFAULT 'scheduled',
    PRIMARY KEY (pickup_id),
    UNIQUE KEY uq_pickups_claim_id (claim_id),
    CONSTRAINT fk_pickups_claim
        FOREIGN KEY (claim_id) REFERENCES Claims (claim_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
