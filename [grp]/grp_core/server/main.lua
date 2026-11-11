CreateThread(function()
    print('-----------------------------------')
    print('[GRP] Serverio modulis paleistas!')
    print('[GRP] Versija: ' .. Config.Version)
    print('-----------------------------------')
end)

local function GetGRPName(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return nil
    end

    local charinfo = player.PlayerData.charinfo

    if not charinfo then
        return nil
    end

    local firstname = charinfo.firstname
    local lastname = charinfo.lastname

    if not firstname or not lastname then
        return nil
    end

    return firstname .. '_' .. lastname
end


RegisterCommand('info', function(source)
    if source == 0 then return end

    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return
    end

    local data = player.PlayerData
    local citizenid = data.citizenid

    local progression = GRP.Database.LoadProgression(citizenid)

    if not progression then
        print('[GRP] Nepavyko uzkrauti statistikos!')
        return
    end

    local name = GetGRPName(source) or 'Nezinomas'

    local playtime = tonumber(progression.playtime) or 0
    local hours = math.floor(playtime / 60)
    local minutes = playtime % 60

    local job = data.job or {}
    local money = data.money or {}

    TriggerClientEvent('grp_core:client:showInfo', source, {
        name = name,
        id = source,
        xp = progression.xp,
        hours = hours,
        minutes = minutes,
        job = job.label or 'Bedarbis',
        working = GRP.Duty.IsWorking(source),
        cash = money.cash or 0,
        bank = money.bank or 0
    })
end, false)

RegisterCommand('testdb', function(source)
    if source == 0 then
        print('[GRP] Komanda skirta tik zaidejams.')
        return
    end

    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        print('[GRP] Zaidejo duomenys nerasti!')
        return
    end

    local citizenid = player.PlayerData.citizenid

    local progression = GRP.Database.LoadProgression(citizenid)

    if not progression then
        print('[GRP] Nepavyko uzkrauti progresijos!')
        return
    end

    print('[GRP] CitizenID: ' .. citizenid)
    print('[GRP] XP: ' .. progression.xp)
    print('[GRP] Playtime: ' .. progression.playtime)
end, false)


RegisterCommand('testjobxp', function(source)
    if source == 0 then return end

    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        print('[GRP] Zaidejas nerastas!')
        return
    end

    local citizenid = player.PlayerData.citizenid
    local jobXP = GRP.Database.LoadJobXP(citizenid)

    if not jobXP then
        print('[GRP] Nepavyko uzkrauti darbu XP!')
        return
    end

    print('[GRP] Teisesaugos XP: ' .. jobXP.law_xp)
    print('[GRP] Taksisto XP: ' .. jobXP.taxi_xp)
    print('[GRP] Mediko XP: ' .. jobXP.medic_xp)
    print('[GRP] Mechaniko XP: ' .. jobXP.mechanic_xp)
    print('[GRP] Tolimu reisu XP: ' .. jobXP.trucking_xp)
    print('[GRP] Darbu be pakvietimo XP: ' .. jobXP.civilian_xp)
end, false)

RegisterCommand('testxp', function(source)
    if source == 0 then return end

    if not IsPlayerAceAllowed(source, 'grp.admin') then
        print('[GRP] Zaidejas neturi teises testuoti XP.')
        return
    end

    local generalSuccess = GRP.Progression.AddXP(source, 10)
    local jobSuccess = GRP.Progression.AddJobXP(source, 'taxi', 5)

    print('[GRP] Bendras XP pridetas: ' .. tostring(generalSuccess))
    print('[GRP] Taksisto XP pridetas: ' .. tostring(jobSuccess))
end, false)

RegisterCommand('testduty', function(source, args)
    if source == 0 then return end

    if not IsPlayerAceAllowed(source, 'grp.admin') then
        return
    end

    local action = args[1]

    if action ~= 'on' and action ~= 'off' then
        print('[GRP] Naudok /testduty on arba off')
        return
    end

    local working = action == 'on'
    local success = GRP.Duty.SetWorking(source, working)

    if success then
        print('[GRP] Darbo rezimas: ' .. tostring(working))
    else
        print('[GRP] Nepavyko pakeisti darbo rezimo!')
    end
end, false)
