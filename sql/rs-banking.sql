CREATE TABLE IF NOT EXISTS `rs_banking_security` (
  `identifier` varchar(80) NOT NULL,
  `pin_hash` char(64) DEFAULT NULL,
  `pin_salt` varchar(180) DEFAULT NULL,
  `failed_attempts` tinyint unsigned NOT NULL DEFAULT 0,
  `blocked_until` bigint DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
