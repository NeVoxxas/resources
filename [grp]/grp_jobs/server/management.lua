GRPJobs = GRPJobs or {}
GRPJobs.Management = {}

-- Darbai su pakvietimu (employment.type = 'invite'):
--   * Direktorių skiria administratorius: /skirtidirektoriu ID DARBOID
--   * Direktorius ir pavaduotojas kviečia: /priimti ID (pakvietimas galioja Config.InviteHours val.)
--   * Pakviestas žaidėjas (su pakankamu XP) įsidarbina įsidarbinimo punkte
--   * Direktorius skiria pavaduotojus ir valdo rangus (Config.Ranks.min - Config.Ranks.max)
--   * Pavaduotojas gali tik tai, kas leista job.management.deputyPermissions

local DEFAULT_DEPUTY_PERMISSIONS = { invite = true, kick = true, setRank = true }
local DIRECTOR_ONLY = { setDeputy = true, addRank = true, removeRank = true, editRank = true }

local manageCooldown = {}

local function Notify(src, message, kind, title)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or 'Darbo valdymas',
        description = message,
        type = kind or 'inform'
    })
end

local function IsInviteJob(cfg)
    return cfg ~= nil and cfg.employment ~= nil and cfg.employment.type == 'invite'
end

local function PlayerData(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return nil end
    return player.PlayerData
end

local function ValidName(name)
    if type(name) ~= 'string' then return nil end

    name = name:gsub('^%s+', ''):gsub('%s+$', '')

    if #name < 2 or #name > 32 or name:find('%c') then
        return nil
    end

    return name
end

local function ModelAllowed(cfg, model)
    for _, entry in ipairs(cfg.vehicle and cfg.vehicle.models or {}) do
        if entry.model == model then return true end
    end

    return false
end

local function UniformKeyValid(cfg, key)
    if key == nil then return true end
    if type(key) ~= 'string' then return false end

    return cfg.uniforms ~= nil and cfg.uniforms[key] ~= nil
end

local function RankList(jobId)
    local cfg = Config.Jobs[jobId]

    return GRPJobs.DB.EnsureRanks(jobId, cfg and cfg.ranks and cfg.ranks.defaults)
end

local function FindRank(ranks, rankId)
    for _, rank in ipairs(ranks) do
        if rank.id == rankId then return rank end
    end

    return nil
end

local function IsNearManagement(src, cfg)
    local mgmt = cfg.management

    if not mgmt or not mgmt.coords then return false end

    return GRPJobs.IsPlayerNear(src, mgmt.coords, mgmt.serverDistance or 5.0)
end

-- -----------------------------------------------------
--                 TEISĖS
-- -----------------------------------------------------

-- 'director' | 'deputy' | nil. Reikia, kad žaidėjas dabar dirbtų šį darbą.
function GRPJobs.Management.GetRole(src, jobId)
    local cfg = Config.Jobs[jobId]
    if not IsInviteJob(cfg) then return nil end

    local data = PlayerData(src)
    if not data or not data.job or data.job.name ~= cfg.jobName then return nil end

    return GRPJobs.DB.GetStaffRole(jobId, data.citizenid)
end

local function CanDo(role, cfg, action)
    if role == 'director' then return true end
    if role ~= 'deputy' or DIRECTOR_ONLY[action] then return false end

    local perms = cfg.management and cfg.management.deputyPermissions
        or DEFAULT_DEPUTY_PERMISSIONS

    return perms[action] == true
end

-- -----------------------------------------------------
--                 ĮSIDARBINIMAS (kviečiama iš employment.lua)
-- -----------------------------------------------------

-- Grąžina: ok, message, isStaff (direktorius / pavaduotojas XP nereikalaujami)
function GRPJobs.Management.CheckInviteAccess(src, jobId)
    local data = PlayerData(src)
    if not data then return false, 'Veikėjas nerastas.' end

    if GRPJobs.DB.GetStaffRole(jobId, data.citizenid) then
        return true, nil, true
    end

    if not GRPJobs.DB.HasValidInvite(jobId, data.citizenid) then
        return false, 'Šiam darbui reikia direktoriaus ar pavaduotojo pakvietimo.'
    end

    return true, nil, false
end

function GRPJobs.Management.OnJoined(src, jobId)
    local data = PlayerData(src)
    if not data then return end

    local cfg = Config.Jobs[jobId]
    local ranks = RankList(jobId)
    local role = GRPJobs.DB.GetStaffRole(jobId, data.citizenid)

    -- Direktorius ir pavaduotojas pradeda nuo aukščiausio rango, kiti nuo žemiausio
    local rankId = role and ranks[#ranks].id or ranks[1].id

    GRPJobs.DB.SetMember(data.citizenid, jobId, rankId)
    GRPJobs.DB.DeleteInvite(jobId, data.citizenid)

    if Config.Debug then
        print(('[GRP JOBS] %s prisijungė prie %s, rangas %d'):format(data.citizenid, cfg.jobName, rankId))
    end
end

-- Kai žaidėjas nebedirba darbo (išėjo, išmestas, admin pakeitė) – išvalome narystę
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    local data = PlayerData(src)
    if not data then return end

    local member = GRPJobs.DB.GetMember(data.citizenid)
    if not member then return end

    local cfg = Config.Jobs[member.job_id]

    if not cfg or not job or job.name ~= cfg.jobName then
        GRPJobs.DB.RemoveMember(data.citizenid)
    end
end)

-- -----------------------------------------------------
--                 RANGAI: TRANSPORTAS IR APRANGA
-- -----------------------------------------------------

-- Žaidėjo rangas darbe su pakvietimu (nil, jei darbas be rangų)
function GRPJobs.Management.GetPlayerRank(src, jobId)
    local cfg = Config.Jobs[jobId]
    if not IsInviteJob(cfg) then return nil end

    local data = PlayerData(src)
    if not data then return nil end

    local member = GRPJobs.DB.GetMember(data.citizenid)
    if not member or member.job_id ~= jobId then return nil end

    return FindRank(RankList(jobId), member.rank_id)
end

-- Sąrašas { model, label }, kuriuos žaidėjas gali gauti
function GRPJobs.Management.GetAllowedVehicles(src, jobId)
    local cfg = Config.Jobs[jobId]
    local models = cfg and cfg.vehicle and cfg.vehicle.models or {}

    local rank = GRPJobs.Management.GetPlayerRank(src, jobId)
    if not rank or not rank.vehicles or #rank.vehicles == 0 then
        return models
    end

    local allowed = {}

    for _, entry in ipairs(models) do
        for _, model in ipairs(rank.vehicles) do
            if model == entry.model then
                allowed[#allowed + 1] = entry
                break
            end
        end
    end

    return allowed
end

-- Uniformos rinkinio raktas pagal rangą (nil = numatytoji)
function GRPJobs.Management.GetUniformPreset(src, jobId)
    local cfg = Config.Jobs[jobId]
    local rank = GRPJobs.Management.GetPlayerRank(src, jobId)

    if rank and rank.uniform and cfg.uniforms and cfg.uniforms[rank.uniform] then
        return rank.uniform
    end

    return nil
end

exports('GetPlayerJobRank', function(src)
    local jobId = GRPJobs.Duty.GetPlayerJob(src)
    if not jobId then return nil end

    local rank = GRPJobs.Management.GetPlayerRank(src, jobId)
    if not rank then return nil end

    return { jobId = jobId, rank = rank.id, name = rank.name }
end)

-- -----------------------------------------------------
--                 VEIKSMAI
-- -----------------------------------------------------

function GRPJobs.Management.Invite(src, jobId, targetSrc)
    local cfg = Config.Jobs[jobId]
    local actor = PlayerData(src)

    if type(targetSrc) ~= 'number' or targetSrc % 1 ~= 0 then
        return false, 'Neteisingas žaidėjo ID.'
    end

    local target = PlayerData(targetSrc)
    if not target then return false, 'Žaidėjas nerastas.' end

    if target.job and target.job.name == cfg.jobName then
        return false, 'Šis žaidėjas jau dirba šį darbą.'
    end

    GRPJobs.DB.CreateInvite(jobId, target.citizenid, actor.citizenid, Config.InviteHours)

    Notify(targetSrc, ('Gavai pakvietimą į darbą „%s“ (galioja %d val.). Įsidarbink darbovietėje.')
        :format(cfg.label, Config.InviteHours), 'success', cfg.label)

    return true, 'Pakvietimas išsiųstas.'
end

local function ResolveTarget(jobId, citizenid)
    if type(citizenid) ~= 'string' then return nil end

    local member = GRPJobs.DB.GetMember(citizenid)
    if not member or member.job_id ~= jobId then return nil end

    return member, GRPJobs.DB.GetStaffRole(jobId, citizenid)
end

-- Ar vykdytojas (role) gali veikti žaidėją, turintį targetRole
local function CanActOn(role, targetRole, actorCid, targetCid)
    if actorCid == targetCid then return false end
    if role == 'director' then return targetRole ~= 'director' end
    return targetRole == nil
end

function GRPJobs.Management.SetRank(src, jobId, role, citizenid, rankId)
    local member, targetRole = ResolveTarget(jobId, citizenid)
    if not member then return false, 'Darbuotojas nerastas.' end

    local actor = PlayerData(src)
    -- Direktorius gali keisti ir savo rangą (kad galėtų naudoti norimą transportą / aprangą)
    local selfChange = role == 'director' and actor.citizenid == citizenid
    if not selfChange and not CanActOn(role, targetRole, actor.citizenid, citizenid) then
        return false, 'Šio darbuotojo rango keisti negali.'
    end

    if type(rankId) ~= 'number' or rankId % 1 ~= 0 then
        return false, 'Neteisingas rangas.'
    end

    local rank = FindRank(RankList(jobId), rankId)
    if not rank then return false, 'Tokio rango nėra.' end

    GRPJobs.DB.SetMemberRank(citizenid, jobId, rankId)

    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        Notify(targetPlayer.PlayerData.source, ('Tavo naujas rangas: %s'):format(rank.name), 'inform')
    end

    return true, ('Rangas pakeistas į „%s“.'):format(rank.name)
end

function GRPJobs.Management.Kick(src, jobId, role, citizenid)
    local cfg = Config.Jobs[jobId]
    local member, targetRole = ResolveTarget(jobId, citizenid)
    if not member then return false, 'Darbuotojas nerastas.' end

    local actor = PlayerData(src)
    if not CanActOn(role, targetRole, actor.citizenid, citizenid) then
        return false, 'Šio darbuotojo išmesti negali.'
    end

    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)

    if targetPlayer then
        local targetSrc = targetPlayer.PlayerData.source
        GRPJobs.Duty.ForceEnd(targetSrc, true)
        exports.qbx_core:SetJob(targetSrc, 'unemployed', 0)
        Notify(targetSrc, ('Buvai atleistas iš darbo „%s“.'):format(cfg.label), 'error', cfg.label)
    else
        -- Atsijungęs žaidėjas: bandome pakeisti darbą pagal citizenid
        pcall(function() exports.qbx_core:SetJob(citizenid, 'unemployed', 0) end)
    end

    GRPJobs.DB.RemoveMember(citizenid)
    GRPJobs.DB.RemoveStaff(jobId, citizenid)

    return true, 'Darbuotojas atleistas.'
end

function GRPJobs.Management.SetDeputy(src, jobId, citizenid, value)
    local member, targetRole = ResolveTarget(jobId, citizenid)
    if not member then return false, 'Darbuotojas nerastas.' end
    if targetRole == 'director' then return false, 'Direktoriaus statuso keisti negalima.' end
    if type(value) ~= 'boolean' then return false, 'Neteisinga reikšmė.' end

    if value then
        GRPJobs.DB.SetStaff(jobId, citizenid, 'deputy', PlayerData(src).citizenid)
    else
        GRPJobs.DB.RemoveStaff(jobId, citizenid)
    end

    return true, value and 'Pavaduotojas paskirtas.' or 'Pavaduotojo statusas nuimtas.'
end

function GRPJobs.Management.AddRank(jobId, name)
    local ranks = RankList(jobId)
    if #ranks >= Config.Ranks.max then
        return false, ('Daugiau nei %d rangų negali būti.'):format(Config.Ranks.max)
    end

    name = ValidName(name)
    if not name then return false, 'Rango pavadinimas turi būti 2-32 simbolių.' end

    GRPJobs.DB.AddRank(jobId, ranks[#ranks].id + 1, name)

    return true, 'Rangas pridėtas.'
end

-- Pašalina aukščiausią rangą (jei neužimtas ir nesumažės žemiau minimumo)
function GRPJobs.Management.RemoveRank(jobId)
    local ranks = RankList(jobId)
    if #ranks <= Config.Ranks.min then
        return false, ('Mažiau nei %d rangų negali būti.'):format(Config.Ranks.min)
    end

    local top = ranks[#ranks]

    if GRPJobs.DB.CountMembersAtRank(jobId, top.id) > 0 then
        return false, 'Aukščiausiame range yra darbuotojų. Pirmiausia perkelk juos.'
    end

    GRPJobs.DB.DeleteRank(jobId, top.id)

    return true, ('Rangas „%s“ pašalintas.'):format(top.name)
end

function GRPJobs.Management.EditRank(jobId, rankId, name, vehicles, uniform)
    local cfg = Config.Jobs[jobId]
    local rank = type(rankId) == 'number' and FindRank(RankList(jobId), rankId)
    if not rank then return false, 'Tokio rango nėra.' end

    name = ValidName(name)
    if not name then return false, 'Rango pavadinimas turi būti 2-32 simbolių.' end

    if vehicles ~= nil then
        if type(vehicles) ~= 'table' then return false, 'Neteisingas transportų sąrašas.' end

        for _, model in ipairs(vehicles) do
            if type(model) ~= 'string' or not ModelAllowed(cfg, model) then
                return false, 'Neleidžiamas transporto modelis.'
            end
        end

        -- Tuščias sąrašas = visi darbo transportai
        if #vehicles == 0 then vehicles = nil end
    end

    if uniform == '' or uniform == 'default' then uniform = nil end

    if not UniformKeyValid(cfg, uniform) then
        return false, 'Tokio aprangos rinkinio nėra.'
    end

    GRPJobs.DB.UpdateRank(jobId, rankId, name, vehicles, uniform)

    return true, 'Rangas atnaujintas.'
end

-- -----------------------------------------------------
--                 VALDYMO MENIU (kliento užklausos)
-- -----------------------------------------------------

local function ValidateManageRequest(src, jobId)
    if type(jobId) ~= 'string' then return nil end

    local cfg = Config.Jobs[jobId]
    if not IsInviteJob(cfg) or not IsNearManagement(src, cfg) then return nil end

    local role = GRPJobs.Management.GetRole(src, jobId)
    if not role then return nil end

    return cfg, role
end

lib.callback.register('grp_jobs:server:getManagement', function(src, jobId)
    local cfg, role = ValidateManageRequest(src, jobId)

    if not cfg then
        Notify(src, 'Tu neturi prieigos prie šio valdymo.', 'error')
        return nil
    end

    local members = GRPJobs.DB.ListMembers(jobId)

    for _, member in ipairs(members) do
        member.online = exports.qbx_core:GetPlayerByCitizenId(member.citizenid) ~= nil
    end

    local uniforms = {}
    for key in pairs(cfg.uniforms or {}) do
        uniforms[#uniforms + 1] = key
    end
    table.sort(uniforms)

    local perms = {}
    for _, action in ipairs({ 'invite', 'kick', 'setRank', 'setDeputy', 'addRank', 'removeRank', 'editRank' }) do
        perms[action] = CanDo(role, cfg, action)
    end

    return {
        label = cfg.label,
        role = role,
        perms = perms,
        ranks = RankList(jobId),
        members = members,
        models = cfg.vehicle and cfg.vehicle.models or {},
        uniforms = uniforms,
        limits = Config.Ranks
    }
end)

local Actions = {
    invite = function(src, jobId, role, data)
        return GRPJobs.Management.Invite(src, jobId, data.target)
    end,
    setRank = function(src, jobId, role, data)
        return GRPJobs.Management.SetRank(src, jobId, role, data.citizenid, data.rank)
    end,
    kick = function(src, jobId, role, data)
        return GRPJobs.Management.Kick(src, jobId, role, data.citizenid)
    end,
    setDeputy = function(src, jobId, role, data)
        return GRPJobs.Management.SetDeputy(src, jobId, data.citizenid, data.value)
    end,
    addRank = function(src, jobId, role, data)
        return GRPJobs.Management.AddRank(jobId, data.name)
    end,
    removeRank = function(src, jobId)
        return GRPJobs.Management.RemoveRank(jobId)
    end,
    editRank = function(src, jobId, role, data)
        return GRPJobs.Management.EditRank(jobId, data.rank, data.name, data.vehicles, data.uniform)
    end
}

RegisterNetEvent('grp_jobs:server:manage', function(action, jobId, data)
    local src = source

    if type(action) ~= 'string' or type(jobId) ~= 'string' then return end
    if data ~= nil and type(data) ~= 'table' then return end
    data = data or {}

    local handler = Actions[action]
    if not handler then return end

    local now = GetGameTimer()
    if manageCooldown[src] and now - manageCooldown[src] < Config.ManageCooldownMs then return end
    manageCooldown[src] = now

    local cfg, role = ValidateManageRequest(src, jobId)
    if not cfg or not CanDo(role, cfg, action) then
        Notify(src, 'Neturi teisės šiam veiksmui.', 'error')
        return
    end

    local success, message = handler(src, jobId, role, data)
    Notify(src, message, success and 'success' or 'error', cfg.label)
end)

-- -----------------------------------------------------
--                 KOMANDOS
-- -----------------------------------------------------

-- /priimti ID: direktorius arba pavaduotojas pakviečia žaidėją į savo darbą
RegisterCommand('priimti', function(src, args)
    if src == 0 then return end

    local jobId, cfg = GRPJobs.Duty.GetPlayerJob(src)

    if not jobId or not IsInviteJob(cfg) then
        Notify(src, 'Tavo darbe pakvietimų nėra.', 'error')
        return
    end

    local role = GRPJobs.Management.GetRole(src, jobId)

    if not CanDo(role, cfg, 'invite') then
        Notify(src, 'Neturi teisės priimti žmonių.', 'error', cfg.label)
        return
    end

    local success, message = GRPJobs.Management.Invite(src, jobId, tonumber(args[1]))
    Notify(src, message, success and 'success' or 'error', cfg.label)
end, false)

local function IsAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'grp.admin')
end

local function Reply(src, message)
    if src == 0 then
        print('[GRP JOBS] ' .. message)
    else
        Notify(src, message, 'inform', 'Administravimas')
    end
end

-- /skirtidirektoriu ID DARBOID  (pvz. /skirtidirektoriu 5 taxi)
RegisterCommand('skirtidirektoriu', function(src, args)
    if not IsAdmin(src) then return end

    local targetSrc, jobId = tonumber(args[1]), args[2]
    local cfg = jobId and Config.Jobs[jobId]

    if not targetSrc or not IsInviteJob(cfg) then
        Reply(src, 'Naudojimas: /skirtidirektoriu ID DARBOID (darbas turi būti su pakvietimu)')
        return
    end

    local target = PlayerData(targetSrc)
    if not target then Reply(src, 'Žaidėjas nerastas.') return end

    GRPJobs.DB.SetStaff(jobId, target.citizenid, 'director', nil)
    Notify(targetSrc, ('Tapai darbo „%s“ direktoriumi. Įsidarbink darbovietėje ir naudok /priimti.')
        :format(cfg.label), 'success', cfg.label)
    Reply(src, ('Žaidėjas %d paskirtas darbo %s direktoriumi.'):format(targetSrc, jobId))
end, false)

-- /nuimtidirektoriu ID DARBOID
RegisterCommand('nuimtidirektoriu', function(src, args)
    if not IsAdmin(src) then return end

    local targetSrc, jobId = tonumber(args[1]), args[2]
    local cfg = jobId and Config.Jobs[jobId]

    if not targetSrc or not IsInviteJob(cfg) then
        Reply(src, 'Naudojimas: /nuimtidirektoriu ID DARBOID')
        return
    end

    local target = PlayerData(targetSrc)
    if not target then Reply(src, 'Žaidėjas nerastas.') return end

    if GRPJobs.DB.GetStaffRole(jobId, target.citizenid) ~= 'director' then
        Reply(src, 'Šis žaidėjas nėra šio darbo direktorius.')
        return
    end

    GRPJobs.DB.RemoveStaff(jobId, target.citizenid)
    Reply(src, ('Direktoriaus statusas nuimtas žaidėjui %d.'):format(targetSrc))
end, false)

AddEventHandler('playerDropped', function()
    manageCooldown[source] = nil
end)
