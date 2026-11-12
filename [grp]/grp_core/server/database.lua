
GRP = GRP or {}
GRP.Database = {}

function GRP.Database.LoadProgression(citizenid)
    if not citizenid or citizenid == '' then
        print('[GRP] Klaida: nenurodytas citizenid!')
        return nil
    end

    local progression = MySQL.single.await(
        'SELECT xp, playtime FROM grp_progression WHERE citizenid = ?',
        { citizenid }
    )

    if progression then
        return progression
    end

    local inserted = MySQL.insert.await(
        'INSERT IGNORE INTO grp_progression (citizenid) VALUES (?)',
        { citizenid }
    )

    if inserted == nil then
        print('[GRP] Nepavyko sukurti progresijos iraso!')
        return nil
    end

    return MySQL.single.await(
        'SELECT xp, playtime FROM grp_progression WHERE citizenid = ?',
        { citizenid }
    )
end

function GRP.Database.LoadJobXP(citizenid)
    if not citizenid or citizenid == '' then
        print('[GRP] Klaida: nenurodytas citizenid!')
        return nil
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO grp_job_xp (citizenid)
        VALUES (?)
    ]], { citizenid })

    local jobXP = MySQL.single.await([[
        SELECT
            law_xp,
            taxi_xp,
            medic_xp,
            mechanic_xp,
            trucking_xp,
            civilian_xp
        FROM grp_job_xp
        WHERE citizenid = ?
    ]], { citizenid })

    return jobXP
end

function GRP.Database.GetPlayerID(citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' then
        return nil
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO grp_players (citizenid)
        VALUES (?)
    ]], { citizenid })

    local id = MySQL.scalar.await([[
        SELECT id
        FROM grp_players
        WHERE citizenid = ?
    ]], { citizenid })

    return id
end
