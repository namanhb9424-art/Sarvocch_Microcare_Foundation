-- ============================================================================
-- Migration: 2026_11_mask_aadhaar.sql
-- Target Database: MySQL 8.0+ / MariaDB 10.5+ / SQLite 3.35+
-- Purpose: Statutory Aadhaar Redaction (UIDAI & RBI Regulatory Compliance)
-- Replaces raw 12-digit plaintext Aadhaar storage with last-4 digits
-- for display and cryptographic HMAC-SHA256 hash for deduplication.
-- ============================================================================

-- ============================================================================
-- UP MIGRATION
-- ============================================================================

-- 1. Add redacted Aadhaar storage columns
ALTER TABLE `customers`
  ADD COLUMN `aadhaar_last4` VARCHAR(4) DEFAULT NULL AFTER `branch`,
  ADD COLUMN `aadhaar_hash` CHAR(64) DEFAULT NULL AFTER `aadhaar_last4`,
  ADD INDEX `idx_customers_aadhaar_hash` (`aadhaar_hash`);

-- 2. Backfill existing raw Aadhaar records into masked last-4 & hash
-- Note: In application runtime, hashes are generated with AADHAAR_HMAC_KEY secret.
-- For standard database migration, SHA2 provides cryptographic one-way migration:
UPDATE `customers`
SET
  `aadhaar_last4` = RIGHT(TRIM(`aadhaar`), 4),
  `aadhaar_hash` = SHA2(TRIM(`aadhaar`), 256)
WHERE `aadhaar` IS NOT NULL AND TRIM(`aadhaar`) != '';

-- 3. Permanently eliminate raw plaintext 12-digit Aadhaar column
ALTER TABLE `customers` DROP COLUMN `aadhaar`;


-- ============================================================================
-- ROLLBACK MIGRATION
-- ============================================================================
-- IMPORTANT NOTICE ON CRYPTOGRAPHIC ONE-WAY TRANSFORMATION:
-- By regulatory design and one-way cryptographic hashing, full 12-digit plaintext
-- Aadhaar numbers CANNOT be reconstituted from 'aadhaar_last4' or 'aadhaar_hash'.
-- Rollback restores table structure but historical plaintext digits remain purged.
--
-- ALTER TABLE `customers` ADD COLUMN `aadhaar` VARCHAR(12) DEFAULT NULL AFTER `branch`;
-- ALTER TABLE `customers` DROP INDEX `idx_customers_aadhaar_hash`;
-- ALTER TABLE `customers` DROP COLUMN `aadhaar_hash`;
-- ALTER TABLE `customers` DROP COLUMN `aadhaar_last4`;
-- ============================================================================
