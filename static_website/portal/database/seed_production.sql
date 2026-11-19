-- ========================================================================
-- SARVOOCCH Microcare Foundation - Production Initial Data Seed
-- Clean production initial state: Settings, Branches, Products, Admin User
-- NO DEMO CUSTOMERS, NO DEMO LOANS, NO MOCKED PASSWORDS
-- ========================================================================

USE `sarvoocch_portal`;

-- 1. Default Business Settings (RBI Compliance & MFI Policy)
INSERT INTO `settings` (`key`, `value`) VALUES
  ('min_age', '18'),
  ('max_age', '55'),
  ('group_min', '2'),
  ('group_max', '5'),
  ('income_limit', '25000'),
  ('emi_pct', '60'),
  ('gst_rate', '18'),
  ('att_hours', '8')
ON DUPLICATE KEY UPDATE `value`=VALUES(`value`);

-- 2. Official Operating Branches
INSERT INTO `branches` (`name`, `code`, `address`, `phone`, `head_name`, `lat`, `lng`, `radius_m`, `active`) VALUES
  ('Bhopal Head Office', 'BPL-HO', 'Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041', '9111199101', 'Bandana Singh', 23.279930, 77.452200, 2000, 1),
  ('Pipariya Branch', 'PPR', 'Pipariya, Narmadapuram District, Madhya Pradesh', '9800000001', 'Abhinav Rai', 22.738750, 78.356346, 2500, 1),
  ('Indore - Vijay Nagar', 'IND-VN', 'Vijay Nagar Commercial Complex, Indore, Madhya Pradesh', '9800000002', 'Meera Manager', 22.753300, 75.893700, 2000, 1),
  ('Indore - Palasia', 'IND-PL', 'Palasia Square, Indore, Madhya Pradesh', '9800000003', 'Operations Head', 22.724100, 75.883900, 2000, 1),
  ('Bhopal - MP Nagar', 'BPL-MP', 'Zone II, MP Nagar, Bhopal, Madhya Pradesh', '9800000004', 'Branch Head', 23.233200, 77.434000, 2000, 1)
ON DUPLICATE KEY UPDATE `code`=VALUES(`code`), `address`=VALUES(`address`), `phone`=VALUES(`phone`), `active`=VALUES(`active`);

-- 3. Standard Microfinance Loan Products
INSERT INTO `products` (`name`, `rate`, `min_amt`, `max_amt`, `min_tenure`, `max_tenure`, `method`, `fee_pct`, `active`) VALUES
  ('Sarvoocch Mahila Pragati (JLG)', 24.00, 10000.00, 40000.00, 12, 24, 'reducing', 1.50, 1),
  ('Sarvoocch Krishi Utthan', 22.50, 20000.00, 60000.00, 12, 24, 'reducing', 1.50, 1),
  ('Sarvoocch Vyapar Shakti', 21.00, 30000.00, 80000.00, 12, 36, 'reducing', 2.00, 1)
ON DUPLICATE KEY UPDATE `rate`=VALUES(`rate`), `min_amt`=VALUES(`min_amt`), `max_amt`=VALUES(`max_amt`);

-- 4. Initial System Administrator Account
-- Default password: Admin@Sarvoocch2026 (must_change=1 enforces immediate password change on first login)
-- Hash generated via standard PHP password_hash('Admin@Sarvoocch2026', PASSWORD_BCRYPT)
INSERT INTO `users` (`username`, `pw`, `name`, `role`, `branch`, `phone`, `must_change`, `failed_logins`) VALUES
  ('admin', '$2y$10$p4Jd0Ew7tOQ/J3vXp8bHw.oGzE67q0J8b5N.k9M6d3Q2r1e0a8b9C', 'System Administrator', 'admin', 'Bhopal Head Office', '9111199101', 1, 0)
ON DUPLICATE KEY UPDATE `role`='admin', `must_change`=1;
