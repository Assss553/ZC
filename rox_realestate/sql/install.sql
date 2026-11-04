-- rox_realestate (tables are also created automatically on resource start)

CREATE TABLE IF NOT EXISTS `rox_properties` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `label` VARCHAR(64) NOT NULL,
        `interior` VARCHAR(64) NOT NULL,
        `image` VARCHAR(255) DEFAULT NULL,
        `ptype` VARCHAR(8) NOT NULL DEFAULT 'sale',
        `price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `rent_days` INT NOT NULL DEFAULT 7,
        `status` VARCHAR(16) NOT NULL DEFAULT 'available',
        `owner` VARCHAR(64) DEFAULT NULL,
        `owner_name` VARCHAR(64) DEFAULT NULL,
        `realtor` VARCHAR(64) DEFAULT NULL,
        `realtor_name` VARCHAR(64) DEFAULT NULL,
        `door` LONGTEXT NOT NULL,
        `street` VARCHAR(128) DEFAULT NULL,
        `locked` TINYINT(1) NOT NULL DEFAULT 1,
        `keyholders` LONGTEXT DEFAULT NULL,
        `sale_price` INT DEFAULT NULL,
        `rent_due` INT DEFAULT NULL,
        `overdue` INT NOT NULL DEFAULT 0,
        `created_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`owner`)
    );

CREATE TABLE IF NOT EXISTS `rox_contracts` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `property_id` INT NOT NULL,
        `ctype` VARCHAR(8) NOT NULL DEFAULT 'sale',
        `price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `rent_days` INT NOT NULL DEFAULT 7,
        `buyer` VARCHAR(64) NOT NULL,
        `buyer_name` VARCHAR(64) DEFAULT NULL,
        `realtor` VARCHAR(64) DEFAULT NULL,
        `realtor_name` VARCHAR(64) DEFAULT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
        `signature` VARCHAR(64) DEFAULT NULL,
        `created_at` INT NOT NULL DEFAULT 0,
        `signed_at` INT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `buyer` (`buyer`),
        KEY `property_id` (`property_id`)
    );

CREATE TABLE IF NOT EXISTS `rox_furniture` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `property_id` INT NOT NULL,
        `model` VARCHAR(64) NOT NULL,
        `price` INT NOT NULL DEFAULT 0,
        `placed` TINYINT(1) NOT NULL DEFAULT 0,
        `x` FLOAT DEFAULT NULL, `y` FLOAT DEFAULT NULL, `z` FLOAT DEFAULT NULL,
        `rx` FLOAT DEFAULT 0, `ry` FLOAT DEFAULT 0, `rz` FLOAT DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `property_id` (`property_id`)
    );

CREATE TABLE IF NOT EXISTS `rox_payouts` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(64) NOT NULL,
        `amount` INT NOT NULL,
        `reason` VARCHAR(128) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `identifier` (`identifier`)
    );
