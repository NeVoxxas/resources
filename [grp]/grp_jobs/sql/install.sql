-- grp_jobs lentelės. Resursas jas sukuria pats paleidimo metu (CREATE TABLE IF NOT EXISTS),
-- šį failą galima paleisti ir rankiniu būdu.

CREATE TABLE IF NOT EXISTS `grp_job_staff` (
    `job_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` ENUM('director','deputy') NOT NULL,
    `appointed_by` VARCHAR(50) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`job_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grp_job_members` (
    `citizenid` VARCHAR(50) NOT NULL,
    `job_id` VARCHAR(50) NOT NULL,
    `rank_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `job_id` (`job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grp_job_ranks` (
    `job_id` VARCHAR(50) NOT NULL,
    `rank_id` TINYINT UNSIGNED NOT NULL,
    `name` VARCHAR(32) NOT NULL,
    `vehicles` TEXT NULL,
    `uniform` VARCHAR(32) NULL,
    PRIMARY KEY (`job_id`, `rank_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grp_job_invites` (
    `job_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `invited_by` VARCHAR(50) NULL,
    `expires_at` DATETIME NOT NULL,
    PRIMARY KEY (`job_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
