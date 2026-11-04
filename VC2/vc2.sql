-- Created automatically by VC2 on start. Only run this manually if your DB user cannot create tables.
CREATE TABLE IF NOT EXISTS `vc2_vehicles` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `plate` VARCHAR(12) NOT NULL UNIQUE,
  `owner` VARCHAR(64) NOT NULL,
  `owner_name` VARCHAR(64) DEFAULT NULL,
  `model` VARCHAR(64) NOT NULL,
  `color` INT DEFAULT 1,
  `props` LONGTEXT DEFAULT NULL,
  `origin` VARCHAR(16) DEFAULT 'showroom',
  `price` INT DEFAULT 0,
  `impounded` TINYINT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`owner`)
);
CREATE TABLE IF NOT EXISTS `vc2_orders` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `owner` VARCHAR(64) NOT NULL,
  `owner_name` VARCHAR(64) DEFAULT NULL,
  `base` VARCHAR(64) DEFAULT NULL,
  `type` VARCHAR(16) DEFAULT NULL,
  `color` INT DEFAULT 1,
  `budget` INT DEFAULT 0,
  `specs` TEXT,
  `status` VARCHAR(16) DEFAULT 'pending',
  `model` VARCHAR(64) DEFAULT NULL,
  `price` INT DEFAULT NULL,
  `note` VARCHAR(255) DEFAULT NULL,
  `handled_by` VARCHAR(64) DEFAULT NULL,
  `plate` VARCHAR(12) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`owner`)
);
