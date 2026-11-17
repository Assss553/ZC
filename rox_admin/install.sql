-- ROX Store | rox_admin | run once on your Qbox database
CREATE TABLE IF NOT EXISTS `rox_admin_sessions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `license` VARCHAR(64), `steam` VARCHAR(64), `steam_name` VARCHAR(100), `discord` VARCHAR(64), `ip` VARCHAR(64),
  `server_id` INT, `citizenid` VARCHAR(50), `char_name` VARCHAR(100),
  `joined_at` INT NOT NULL, `left_at` INT NULL, `duration` INT NULL,
  `quit_type` VARCHAR(20) NULL, `quit_reason` VARCHAR(255) NULL,
  INDEX (`license`), INDEX (`steam`), INDEX (`citizenid`), INDEX (`joined_at`)
);
CREATE TABLE IF NOT EXISTS `rox_admin_charlog` (
  `id` INT AUTO_INCREMENT PRIMARY KEY, `session_id` INT, `license` VARCHAR(64), `citizenid` VARCHAR(50),
  `char_name` VARCHAR(100), `at` INT NOT NULL, INDEX (`citizenid`), INDEX (`license`)
);
CREATE TABLE IF NOT EXISTS `rox_admin_actions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY, `admin_license` VARCHAR(64), `admin_name` VARCHAR(100),
  `action` VARCHAR(50), `target_license` VARCHAR(64), `target_cid` VARCHAR(50), `target_name` VARCHAR(100),
  `details` TEXT, `at` INT NOT NULL, INDEX (`target_license`), INDEX (`at`)
);
CREATE TABLE IF NOT EXISTS `rox_admin_staff` (
  `identifier` VARCHAR(64) PRIMARY KEY, `name` VARCHAR(100), `rank` VARCHAR(20) NOT NULL, `added_by` VARCHAR(100), `at` INT
);
CREATE TABLE IF NOT EXISTS `rox_admin_perms` (
  `rank` VARCHAR(20), `perm` VARCHAR(40), `allowed` TINYINT(1) NOT NULL, PRIMARY KEY (`rank`, `perm`)
);
CREATE TABLE IF NOT EXISTS `rox_admin_coords` (
  `id` INT AUTO_INCREMENT PRIMARY KEY, `label` VARCHAR(80), `x` FLOAT, `y` FLOAT, `z` FLOAT, `h` FLOAT,
  `shared` TINYINT(1) DEFAULT 1, `owner_license` VARCHAR(64), `owner_name` VARCHAR(100), `at` INT
);
