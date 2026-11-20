-- ========================================================================
-- SARVOOCCH Microcare Foundation - Production MySQL Database Schema
-- Optimized for Hostinger LiteSpeed + PHP 8.3 + MySQL 8.0 / MariaDB 10.11
-- ========================================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+05:30";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `username` VARCHAR(60) NOT NULL UNIQUE,
  `pw` VARCHAR(255) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `role` ENUM('admin','manager','underwriter','field_agent','customer') NOT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `customer_id` INT UNSIGNED DEFAULT NULL,
  `lat` DOUBLE DEFAULT NULL,
  `lng` DOUBLE DEFAULT NULL,
  `loc_at` DATETIME DEFAULT NULL,
  `must_change` TINYINT(1) NOT NULL DEFAULT 0,
  `failed_logins` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_failed` DATETIME DEFAULT NULL,
  `locked_until` DATETIME DEFAULT NULL,
  INDEX `idx_users_role` (`role`),
  INDEX `idx_users_branch` (`branch`),
  INDEX `idx_users_customer` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Employees Table
CREATE TABLE IF NOT EXISTS `employees` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED DEFAULT NULL,
  `name` VARCHAR(120) NOT NULL,
  `designation` VARCHAR(100) DEFAULT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `manager_id` INT UNSIGNED DEFAULT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `email` VARCHAR(120) DEFAULT NULL,
  `joined` DATE DEFAULT NULL,
  `status` ENUM('active','inactive','resigned') DEFAULT 'active',
  `bg_check` ENUM('pending','cleared','flagged') DEFAULT 'pending',
  `docs` JSON DEFAULT NULL,
  `salary` DECIMAL(12,2) DEFAULT 0.00,
  INDEX `idx_emp_user` (`user_id`),
  INDEX `idx_emp_branch` (`branch`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Customers Table
CREATE TABLE IF NOT EXISTS `customers` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(120) NOT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `dob` DATE DEFAULT NULL,
  `address` TEXT DEFAULT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `agent_id` INT UNSIGNED DEFAULT NULL,
  `stage` VARCHAR(50) DEFAULT 'lead',
  `aadhaar_last4` VARCHAR(4) DEFAULT NULL,
  `aadhaar_hash` CHAR(64) DEFAULT NULL,
  `pan` VARCHAR(10) DEFAULT NULL,
  `voter` VARCHAR(20) DEFAULT NULL,
  `kyc_status` ENUM('pending','verified','rejected') DEFAULT 'pending',
  `wa_verified` TINYINT(1) DEFAULT 0,
  `wa_otp` VARCHAR(10) DEFAULT NULL,
  `created` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_customers_branch` (`branch`),
  INDEX `idx_customers_agent` (`agent_id`),
  INDEX `idx_customers_phone` (`phone`),
  INDEX `idx_customers_stage` (`stage`),
  INDEX `idx_customers_aadhaar_hash` (`aadhaar_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Communication Logs
CREATE TABLE IF NOT EXISTS `comm_logs` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT UNSIGNED NOT NULL,
  `channel` VARCHAR(50) DEFAULT NULL,
  `note` TEXT DEFAULT NULL,
  `by_name` VARCHAR(120) DEFAULT NULL,
  `at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_comm_cust` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Loan Products
CREATE TABLE IF NOT EXISTS `products` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(120) NOT NULL,
  `rate` DECIMAL(5,2) NOT NULL,
  `min_amt` DECIMAL(12,2) NOT NULL,
  `max_amt` DECIMAL(12,2) NOT NULL,
  `min_tenure` INT NOT NULL,
  `max_tenure` INT NOT NULL,
  `method` ENUM('reducing','flat') DEFAULT 'reducing',
  `fee_pct` DECIMAL(5,2) DEFAULT 1.50,
  `active` TINYINT(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Loan Applications
CREATE TABLE IF NOT EXISTS `applications` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT UNSIGNED NOT NULL,
  `product_id` INT UNSIGNED NOT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `tenure` INT NOT NULL,
  `rate` DECIMAL(5,2) NOT NULL,
  `purpose` VARCHAR(255) DEFAULT NULL,
  `income` DECIMAL(12,2) DEFAULT 0.00,
  `occupation` VARCHAR(120) DEFAULT NULL,
  `employer` VARCHAR(120) DEFAULT NULL,
  `co_name` VARCHAR(120) DEFAULT NULL,
  `co_phone` VARCHAR(20) DEFAULT NULL,
  `co_relation` VARCHAR(50) DEFAULT NULL,
  `co_income` DECIMAL(12,2) DEFAULT 0.00,
  `status` VARCHAR(50) DEFAULT 'submitted',
  `agent_id` INT UNSIGNED DEFAULT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `created` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `remarks` TEXT DEFAULT NULL,
  `docs` JSON DEFAULT NULL,
  INDEX `idx_app_cust` (`customer_id`),
  INDEX `idx_app_status` (`status`),
  INDEX `idx_app_branch` (`branch`),
  INDEX `idx_app_agent` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Loans
CREATE TABLE IF NOT EXISTS `loans` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `application_id` INT UNSIGNED NOT NULL,
  `customer_id` INT UNSIGNED NOT NULL,
  `product_id` INT UNSIGNED NOT NULL,
  `principal` DECIMAL(12,2) NOT NULL,
  `rate` DECIMAL(5,2) NOT NULL,
  `tenure` INT NOT NULL,
  `method` ENUM('reducing','flat') DEFAULT 'reducing',
  `emi` DECIMAL(12,2) NOT NULL,
  `start_date` DATE NOT NULL,
  `status` ENUM('active','closed','defaulted') DEFAULT 'active',
  `closure_date` DATE DEFAULT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `agent_id` INT UNSIGNED DEFAULT NULL,
  INDEX `idx_loans_cust` (`customer_id`),
  INDEX `idx_loans_status` (`status`),
  INDEX `idx_loans_branch` (`branch`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Repayment Schedule
CREATE TABLE IF NOT EXISTS `schedule` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_id` INT UNSIGNED NOT NULL,
  `no` INT NOT NULL,
  `due_date` DATE NOT NULL,
  `emi` DECIMAL(12,2) NOT NULL,
  `principal` DECIMAL(12,2) NOT NULL,
  `interest` DECIMAL(12,2) NOT NULL,
  `balance` DECIMAL(12,2) NOT NULL,
  `paid` TINYINT(1) DEFAULT 0,
  `paid_on` DATE DEFAULT NULL,
  INDEX `idx_sched_loan` (`loan_id`),
  INDEX `idx_sched_due` (`due_date`),
  INDEX `idx_sched_paid` (`paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Payments
CREATE TABLE IF NOT EXISTS `payments` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_id` INT UNSIGNED NOT NULL,
  `schedule_id` INT UNSIGNED DEFAULT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `channel` VARCHAR(50) DEFAULT 'CASH',
  `ref` VARCHAR(100) DEFAULT NULL,
  `at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_pay_loan` (`loan_id`),
  INDEX `idx_pay_at` (`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Mandates / eNACH
CREATE TABLE IF NOT EXISTS `mandates` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_id` INT UNSIGNED NOT NULL,
  `mtype` VARCHAR(50) DEFAULT 'enach',
  `bank` VARCHAR(120) DEFAULT NULL,
  `acct_last4` VARCHAR(10) DEFAULT NULL,
  `status` ENUM('active','inactive','pending','rejected') DEFAULT 'pending',
  `created` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_mandate_loan` (`loan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Tasks (Field Operations)
CREATE TABLE IF NOT EXISTS `tasks` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `title` VARCHAR(255) NOT NULL,
  `customer_id` INT UNSIGNED DEFAULT NULL,
  `ttype` VARCHAR(50) DEFAULT 'visit',
  `lat` DOUBLE DEFAULT NULL,
  `lng` DOUBLE DEFAULT NULL,
  `due_date` DATE DEFAULT NULL,
  `officer_id` INT UNSIGNED DEFAULT NULL,
  `status` ENUM('open','done','cancelled') DEFAULT 'open',
  `collected` DECIMAL(12,2) DEFAULT 0.00,
  `notes` TEXT DEFAULT NULL,
  `done_at` DATETIME DEFAULT NULL,
  INDEX `idx_tasks_officer` (`officer_id`),
  INDEX `idx_tasks_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Attendance
CREATE TABLE IF NOT EXISTS `attendance` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `day` DATE NOT NULL,
  `in_time` TIME DEFAULT NULL,
  `out_time` TIME DEFAULT NULL,
  `lat` DOUBLE DEFAULT NULL,
  `lng` DOUBLE DEFAULT NULL,
  UNIQUE KEY `uk_user_day` (`user_id`, `day`),
  INDEX `idx_att_day` (`day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Branches
CREATE TABLE IF NOT EXISTS `branches` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(120) NOT NULL UNIQUE,
  `code` VARCHAR(20) NOT NULL,
  `address` TEXT DEFAULT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `head_name` VARCHAR(120) DEFAULT NULL,
  `lat` DOUBLE DEFAULT NULL,
  `lng` DOUBLE DEFAULT NULL,
  `radius_m` INT DEFAULT 2000,
  `active` TINYINT(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Holidays
CREATE TABLE IF NOT EXISTS `holidays` (
  `day` DATE PRIMARY KEY,
  `name` VARCHAR(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Settings
CREATE TABLE IF NOT EXISTS `settings` (
  `key` VARCHAR(60) PRIMARY KEY,
  `value` TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Attendance Requests
CREATE TABLE IF NOT EXISTS `att_requests` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `branch` VARCHAR(100) DEFAULT NULL,
  `day` DATE NOT NULL,
  `in_time` TIME DEFAULT NULL,
  `out_time` TIME DEFAULT NULL,
  `reason` TEXT DEFAULT NULL,
  `status` ENUM('pending','approved','rejected') DEFAULT 'pending',
  `approver_role` VARCHAR(50) DEFAULT NULL,
  `approver_id` INT UNSIGNED DEFAULT NULL,
  `requested_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `decided_by` VARCHAR(120) DEFAULT NULL,
  `decided_at` DATETIME DEFAULT NULL,
  `remarks` TEXT DEFAULT NULL,
  INDEX `idx_att_req_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. Leaves
CREATE TABLE IF NOT EXISTS `leaves` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `from_d` DATE NOT NULL,
  `to_d` DATE NOT NULL,
  `reason` TEXT DEFAULT NULL,
  `status` ENUM('pending','approved','rejected') DEFAULT 'pending',
  INDEX `idx_leaves_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Performance Reviews
CREATE TABLE IF NOT EXISTS `perf` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `period` VARCHAR(50) NOT NULL,
  `rating` INT NOT NULL,
  `notes` TEXT DEFAULT NULL,
  `by_name` VARCHAR(120) DEFAULT NULL,
  INDEX `idx_perf_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Offline Sync Log
CREATE TABLE IF NOT EXISTS `sync_log` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `uuid` VARCHAR(64) NOT NULL UNIQUE,
  `user_id` INT UNSIGNED NOT NULL,
  `payload` LONGTEXT DEFAULT NULL,
  `captured_at` DATETIME DEFAULT NULL,
  `synced_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Customer KYC Forms (Comprehensive Field Parity)
CREATE TABLE IF NOT EXISTS `kyc_forms` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT UNSIGNED NOT NULL UNIQUE,
  `created_by` INT UNSIGNED DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `form_date` DATE DEFAULT NULL,
  `center_no` VARCHAR(50) DEFAULT NULL,
  `group_no` VARCHAR(50) DEFAULT NULL,
  `guardian_type` VARCHAR(50) DEFAULT NULL,
  `guardian_name` VARCHAR(120) DEFAULT NULL,
  `education` VARCHAR(100) DEFAULT NULL,
  `religion` VARCHAR(50) DEFAULT NULL,
  `category` VARCHAR(50) DEFAULT NULL,
  `house_no` VARCHAR(100) DEFAULT NULL,
  `village` VARCHAR(100) DEFAULT NULL,
  `post_office` VARCHAR(100) DEFAULT NULL,
  `district` VARCHAR(100) DEFAULT NULL,
  `state` VARCHAR(100) DEFAULT 'Madhya Pradesh',
  `pincode` VARCHAR(10) DEFAULT NULL,
  `family` JSON DEFAULT NULL,
  `house_type` VARCHAR(50) DEFAULT NULL,
  `land_ha` DECIMAL(8,2) DEFAULT 0.00,
  `livestock` VARCHAR(255) DEFAULT NULL,
  `bank_name` VARCHAR(120) DEFAULT NULL,
  `bank_acct` VARCHAR(50) DEFAULT NULL,
  `passbook_name` VARCHAR(120) DEFAULT NULL,
  `poverty_line` VARCHAR(20) DEFAULT NULL,
  `dist_center_m` DECIMAL(8,2) DEFAULT 0.00,
  `dist_branch_km` DECIMAL(8,2) DEFAULT 0.00,
  `relative_in_center` VARCHAR(10) DEFAULT 'No',
  `relative_name` VARCHAR(120) DEFAULT NULL,
  `annual_income` DECIMAL(12,2) DEFAULT 0.00,
  `other_loans` INT DEFAULT 0,
  `current_debt` DECIMAL(12,2) DEFAULT 0.00,
  `repay_freq` VARCHAR(20) DEFAULT 'Monthly',
  `photo` VARCHAR(255) DEFAULT NULL,
  `h_name` VARCHAR(120) DEFAULT NULL,
  `h_father` VARCHAR(120) DEFAULT NULL,
  `h_dob` DATE DEFAULT NULL,
  `h_address` TEXT DEFAULT NULL,
  `h_photo` VARCHAR(255) DEFAULT NULL,
  `consent_given` TINYINT(1) DEFAULT 0,
  `consent_date` DATE DEFAULT NULL,
  `declaration` TINYINT(1) DEFAULT 0,
  `bureau_consent` TINYINT(1) DEFAULT 0,
  `address_verified` TINYINT(1) DEFAULT 0,
  `verified_by` VARCHAR(120) DEFAULT NULL,
  `verified_on` DATE DEFAULT NULL,
  `verify_remarks` TEXT DEFAULT NULL,
  `signed_copy` VARCHAR(255) DEFAULT NULL,
  `co_name` VARCHAR(120) DEFAULT NULL,
  `co_phone` VARCHAR(20) DEFAULT NULL,
  `co_relation` VARCHAR(50) DEFAULT NULL,
  `co_income` DECIMAL(12,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Application Extra Details
CREATE TABLE IF NOT EXISTS `app_extra` (
  `application_id` INT UNSIGNED PRIMARY KEY,
  `prev_loans` TEXT DEFAULT NULL,
  `insurance_wanted` VARCHAR(10) DEFAULT 'Yes',
  `insurance_for` VARCHAR(50) DEFAULT 'Borrower + Spouse',
  `docs_deposited` TEXT DEFAULT NULL,
  `docs_other` VARCHAR(255) DEFAULT NULL,
  `inc_agri` DECIMAL(12,2) DEFAULT 0.00,
  `inc_business` DECIMAL(12,2) DEFAULT 0.00,
  `inc_job` DECIMAL(12,2) DEFAULT 0.00,
  `inc_other` DECIMAL(12,2) DEFAULT 0.00,
  `exp_basic` DECIMAL(12,2) DEFAULT 0.00,
  `exp_education` DECIMAL(12,2) DEFAULT 0.00,
  `exp_festival` DECIMAL(12,2) DEFAULT 0.00,
  `exp_health` DECIMAL(12,2) DEFAULT 0.00,
  `exp_emi` DECIMAL(12,2) DEFAULT 0.00,
  `exp_other` DECIMAL(12,2) DEFAULT 0.00,
  `group_rec` DECIMAL(12,2) DEFAULT 0.00,
  `center_rec` DECIMAL(12,2) DEFAULT 0.00,
  `loan_cycle` INT DEFAULT 1,
  `requested_amt` DECIMAL(12,2) DEFAULT 0.00,
  `income_total` DECIMAL(12,2) DEFAULT 0.00,
  `expense_total` DECIMAL(12,2) DEFAULT 0.00,
  `net_saving` DECIMAL(12,2) DEFAULT 0.00,
  `declaration` TINYINT(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Multi-Stage Approvals
CREATE TABLE IF NOT EXISTS `approvals` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `application_id` INT UNSIGNED NOT NULL,
  `stage` VARCHAR(50) NOT NULL,
  `by_user` VARCHAR(120) NOT NULL,
  `by_role` VARCHAR(50) NOT NULL,
  `amount` DECIMAL(12,2) DEFAULT NULL,
  `remarks` TEXT DEFAULT NULL,
  `at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_approvals_app` (`application_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Pre-GRT Group Assessment
CREATE TABLE IF NOT EXISTS `pregrt` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `branch` VARCHAR(100) NOT NULL,
  `center_no` VARCHAR(50) NOT NULL,
  `group_no` VARCHAR(50) NOT NULL,
  `village` VARCHAR(100) DEFAULT NULL,
  `district` VARCHAR(100) DEFAULT NULL,
  `form_date` DATE NOT NULL,
  `pso_name` VARCHAR(120) DEFAULT NULL,
  `pso_empid` VARCHAR(50) DEFAULT NULL,
  `bm_name` VARCHAR(120) DEFAULT NULL,
  `bm_empid` VARCHAR(50) DEFAULT NULL,
  `leader_knows_duties` VARCHAR(20) DEFAULT 'Yes',
  `notes` TEXT DEFAULT NULL,
  `agent_id` INT UNSIGNED DEFAULT NULL,
  `status` ENUM('draft','submitted','verified','rejected') DEFAULT 'draft',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `verified_by` VARCHAR(120) DEFAULT NULL,
  `verified_on` DATE DEFAULT NULL,
  `review_remarks` TEXT DEFAULT NULL,
  INDEX `idx_pregrt_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24. Pre-GRT Members
CREATE TABLE IF NOT EXISTS `pregrt_members` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `pregrt_id` INT UNSIGNED NOT NULL,
  `sno` INT NOT NULL,
  `customer_id` INT UNSIGNED DEFAULT NULL,
  `name` VARCHAR(120) NOT NULL,
  `husband_name` VARCHAR(120) DEFAULT NULL,
  `age` INT DEFAULT NULL,
  `voter_id` VARCHAR(20) DEFAULT NULL,
  `aadhaar4` VARCHAR(4) DEFAULT NULL,
  `family_in_group` VARCHAR(10) DEFAULT 'No',
  `house_type` VARCHAR(50) DEFAULT NULL,
  `land_ha` DECIMAL(8,2) DEFAULT 0.00,
  `livestock` VARCHAR(255) DEFAULT NULL,
  `annual_income` DECIMAL(12,2) DEFAULT 0.00,
  `family_size` INT DEFAULT 1,
  `category` VARCHAR(50) DEFAULT 'General',
  `loan_amount` DECIMAL(12,2) DEFAULT 0.00,
  `purpose` VARCHAR(255) DEFAULT NULL,
  `frequency` VARCHAR(20) DEFAULT 'Monthly',
  `instalments` INT DEFAULT 12,
  `c_meeting` TINYINT(1) DEFAULT 1,
  `c_joint` TINYINT(1) DEFAULT 1,
  `c_fee` TINYINT(1) DEFAULT 1,
  `c_rate` TINYINT(1) DEFAULT 1,
  `c_insurance` TINYINT(1) DEFAULT 1,
  `c_company` TINYINT(1) DEFAULT 1,
  `c_group` TINYINT(1) DEFAULT 1,
  INDEX `idx_pregrt_m_group` (`pregrt_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 25. Security Rate Limits
CREATE TABLE IF NOT EXISTS `rate_limits` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `key` VARCHAR(100) NOT NULL,
  `hit_at` DATETIME NOT NULL,
  INDEX `idx_rate_limit_key_hit` (`key`, `hit_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ========================================================================
-- SARVOOCCH Microcare Foundation - Production Initial Data Seed
-- Clean production initial state: Settings, Branches, Products, Admin User
-- NO DEMO CUSTOMERS, NO DEMO LOANS, NO MOCKED PASSWORDS
-- ========================================================================

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
