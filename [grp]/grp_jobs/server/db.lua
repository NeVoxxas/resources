GRPJobs = GRPJobs or {}
GRPJobs.DB = {}

-- Lentelės sukuriamos automatiškai paleidus resursą (CREATE TABLE IF NOT EXISTS).
-- Ta pati schema yra sql/install.sql.
local schema = {
    [[CREATE TABLE IF NOT EXISTS `grp_job_staff` (
        `job_id` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `role` ENUM('director','deputy') NOT NULL,
        `appointed_by` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`job_id`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grp_job_members` (
        `citizenid` VARCHAR(50) NOT NULL,
        `job_id` VARCHAR(50) NOT NULL,
        `rank_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
        `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`),
        KEY `job_id` (`job_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grp_job_ranks` (
        `job_id` VARCHAR(50) NOT NULL,
        `rank_id` TINYINT UNSIGNED NOT NULL,
        `name` VARCHAR(32) NOT NULL,
        `vehicles` TEXT NULL,
        `uniform` VARCHAR(32) NULL,
        PRIMARY KEY (`job_id`, `rank_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grp_job_invites` (
        `job_id` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `invited_by` VARCHAR(50) NULL,
        `expires_at` DATETIME NOT NULL,
        PRIMARY KEY (`job_id`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
}

GRPJobs.DB.Schema = schema

function GRPJobs.DB.EnsureSchema()
    for _, sql in ipairs(schema) do
        MySQL.query.await(sql)
    end

    MySQL.query.await('DELETE FROM grp_job_invites WHERE expires_at <= NOW()')
end

CreateThread(function()
    GRPJobs.DB.EnsureSchema()
end)

-- -----------------------------------------------------
--                 VADOVAI (direktorius / pavaduotojas)
-- -----------------------------------------------------

function GRPJobs.DB.GetStaffRole(jobId, citizenid)
    local row = MySQL.single.await(
        'SELECT role FROM grp_job_staff WHERE job_id = ? AND citizenid = ?',
        { jobId, citizenid }
    )

    return row and row.role or nil
end

function GRPJobs.DB.SetStaff(jobId, citizenid, role, appointedBy)
    MySQL.query.await([[
        INSERT INTO grp_job_staff (job_id, citizenid, role, appointed_by)
        VALUES (?, ?, ?, NULLIF(?, ''))
        ON DUPLICATE KEY UPDATE role = VALUES(role), appointed_by = VALUES(appointed_by)
    ]], { jobId, citizenid, role, appointedBy or '' })
end

function GRPJobs.DB.RemoveStaff(jobId, citizenid)
    MySQL.query.await(
        'DELETE FROM grp_job_staff WHERE job_id = ? AND citizenid = ?',
        { jobId, citizenid }
    )
end

-- -----------------------------------------------------
--                 DARBUOTOJAI
-- -----------------------------------------------------

function GRPJobs.DB.GetMember(citizenid)
    return MySQL.single.await(
        'SELECT job_id, rank_id FROM grp_job_members WHERE citizenid = ?',
        { citizenid }
    )
end

function GRPJobs.DB.SetMember(citizenid, jobId, rankId)
    MySQL.query.await([[
        INSERT INTO grp_job_members (citizenid, job_id, rank_id)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE job_id = VALUES(job_id), rank_id = VALUES(rank_id)
    ]], { citizenid, jobId, rankId })
end

function GRPJobs.DB.SetMemberRank(citizenid, jobId, rankId)
    return MySQL.update.await(
        'UPDATE grp_job_members SET rank_id = ? WHERE citizenid = ? AND job_id = ?',
        { rankId, citizenid, jobId }
    ) or 0
end

function GRPJobs.DB.RemoveMember(citizenid)
    MySQL.query.await(
        'DELETE FROM grp_job_members WHERE citizenid = ?',
        { citizenid }
    )
end

function GRPJobs.DB.CountMembersAtRank(jobId, rankId)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM grp_job_members WHERE job_id = ? AND rank_id = ?',
        { jobId, rankId }
    )

    return tonumber(count) or 0
end

-- Grąžina darbuotojų sąrašą su vardais (iš qbx_core players lentelės)
function GRPJobs.DB.ListMembers(jobId)
    local rows = MySQL.query.await([[
        SELECT m.citizenid, m.rank_id, s.role, p.charinfo
        FROM grp_job_members m
        LEFT JOIN grp_job_staff s
            ON s.job_id = m.job_id AND s.citizenid = m.citizenid
        LEFT JOIN players p ON p.citizenid COLLATE utf8mb4_unicode_ci = m.citizenid
        WHERE m.job_id = ?
        ORDER BY m.rank_id DESC, m.citizenid ASC
    ]], { jobId }) or {}

    local members = {}

    for _, row in ipairs(rows) do
        local name = row.citizenid
        local ok, info = pcall(json.decode, row.charinfo or '')

        if ok and type(info) == 'table' and info.firstname then
            name = ('%s %s'):format(info.firstname, info.lastname or '')
        end

        members[#members + 1] = {
            citizenid = row.citizenid,
            name = name,
            rank = row.rank_id,
            role = row.role
        }
    end

    return members
end

-- -----------------------------------------------------
--                 RANGAI
-- -----------------------------------------------------

local function DecodeVehicles(raw)
    if not raw or raw == '' then return nil end

    local ok, list = pcall(json.decode, raw)

    if ok and type(list) == 'table' then
        return list
    end

    return nil
end

function GRPJobs.DB.GetRanks(jobId)
    local rows = MySQL.query.await(
        'SELECT rank_id, name, vehicles, uniform FROM grp_job_ranks WHERE job_id = ? ORDER BY rank_id ASC',
        { jobId }
    ) or {}

    local ranks = {}

    for _, row in ipairs(rows) do
        ranks[#ranks + 1] = {
            id = row.rank_id,
            name = row.name,
            vehicles = DecodeVehicles(row.vehicles), -- nil = visi darbo transportai
            uniform = row.uniform                    -- nil = numatytoji uniforma
        }
    end

    return ranks
end

-- Jei darbas dar neturi rangų, sukuria numatytuosius (Config.Ranks.min)
function GRPJobs.DB.EnsureRanks(jobId, names)
    local ranks = GRPJobs.DB.GetRanks(jobId)

    if #ranks > 0 then
        return ranks
    end

    for i = 1, Config.Ranks.min do
        MySQL.query.await(
            'INSERT IGNORE INTO grp_job_ranks (job_id, rank_id, name) VALUES (?, ?, ?)',
            { jobId, i, (names and names[i]) or ('Rangas %d'):format(i) }
        )
    end

    return GRPJobs.DB.GetRanks(jobId)
end

function GRPJobs.DB.AddRank(jobId, rankId, name)
    MySQL.query.await(
        'INSERT INTO grp_job_ranks (job_id, rank_id, name) VALUES (?, ?, ?)',
        { jobId, rankId, name }
    )
end

function GRPJobs.DB.DeleteRank(jobId, rankId)
    MySQL.query.await(
        'DELETE FROM grp_job_ranks WHERE job_id = ? AND rank_id = ?',
        { jobId, rankId }
    )
end

-- vehicles: masyvas modelių arba nil (visi); uniform: rinkinio raktas arba nil
function GRPJobs.DB.UpdateRank(jobId, rankId, name, vehicles, uniform)
    local encoded = nil

    if type(vehicles) == 'table' then
        encoded = json.encode(vehicles)
    end

    -- Be nil parametrų (oxmysql nemėgsta tuščių vietų masyve): '' tampa NULL
    MySQL.query.await(
        "UPDATE grp_job_ranks SET name = ?, vehicles = NULLIF(?, ''), uniform = NULLIF(?, '') WHERE job_id = ? AND rank_id = ?",
        { name, encoded or '', uniform or '', jobId, rankId }
    )
end

-- -----------------------------------------------------
--                 PAKVIETIMAI
-- -----------------------------------------------------

function GRPJobs.DB.CreateInvite(jobId, citizenid, invitedBy, hours)
    MySQL.query.await([[
        INSERT INTO grp_job_invites (job_id, citizenid, invited_by, expires_at)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
        ON DUPLICATE KEY UPDATE
            invited_by = VALUES(invited_by),
            expires_at = VALUES(expires_at)
    ]], { jobId, citizenid, invitedBy, hours })
end

function GRPJobs.DB.HasValidInvite(jobId, citizenid)
    local row = MySQL.single.await(
        'SELECT invited_by FROM grp_job_invites WHERE job_id = ? AND citizenid = ? AND expires_at > NOW()',
        { jobId, citizenid }
    )

    return row ~= nil
end

function GRPJobs.DB.DeleteInvite(jobId, citizenid)
    MySQL.query.await(
        'DELETE FROM grp_job_invites WHERE job_id = ? AND citizenid = ?',
        { jobId, citizenid }
    )
end
