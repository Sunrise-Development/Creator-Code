-- --------------------------------------------
--  Creator Code System SQL Setup
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS `creator_codes` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `data` JSON DEFAULT NULL,
  `creator_name` VARCHAR(100) DEFAULT NULL,
  `uses` INT(11) DEFAULT 0,
  `max_uses` INT(11) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Beispiel-Eintrag
INSERT INTO `creator_codes` (`code`, `data`, `creator_name`, `uses`, `max_uses`)
VALUES
('TEST2025', JSON_OBJECT('reward', '50000$', 'type', 'money'), '', 0, 100);

