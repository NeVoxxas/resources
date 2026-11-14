-- Vadovo valdymo meniu (darbai su pakvietimu). Visas teises tikrina serveris
-- (server/management.lua); čia tik sąsaja.

GRPClient = GRPClient or {}

local ROLE_LABEL = { director = 'Direktorius', deputy = 'Pavaduotojas' }

local function Send(action, jobId, data)
    TriggerServerEvent('grp_jobs:server:manage', action, jobId, data or {})
end

local OpenManagement

-- Po veiksmo perkrauname meniu, kai serveris spėja atnaujinti duomenis
local function Refresh(jobId)
    SetTimeout(700, function()
        OpenManagement(jobId)
    end)
end

local function RankName(data, rankId)
    for _, rank in ipairs(data.ranks) do
        if rank.id == rankId then return rank.name end
    end

    return ('Rangas %d'):format(rankId)
end

local function ShowMember(jobId, data, member)
    local options = {}

    if data.perms.setRank and (member.role ~= 'director' or data.role == 'director') then
        options[#options + 1] = {
            title = 'Keisti rangą',
            description = ('Dabar: %s'):format(RankName(data, member.rank)),
            icon = 'fa-solid fa-arrows-up-down',
            onSelect = function()
                local choices = {}

                for _, rank in ipairs(data.ranks) do
                    choices[#choices + 1] = { value = rank.id, label = ('%d. %s'):format(rank.id, rank.name) }
                end

                local input = lib.inputDialog('Keisti rangą', {
                    { type = 'select', label = 'Naujas rangas', options = choices, default = member.rank, required = true }
                })

                if input then
                    Send('setRank', jobId, { citizenid = member.citizenid, rank = input[1] })
                    Refresh(jobId)
                end
            end
        }
    end

    if data.perms.setDeputy and member.role ~= 'director' then
        local isDeputy = member.role == 'deputy'

        options[#options + 1] = {
            title = isDeputy and 'Nuimti pavaduotojo statusą' or 'Paskirti pavaduotoju',
            icon = 'fa-solid fa-user-shield',
            onSelect = function()
                Send('setDeputy', jobId, { citizenid = member.citizenid, value = not isDeputy })
                Refresh(jobId)
            end
        }
    end

    if data.perms.kick and member.role ~= 'director' then
        options[#options + 1] = {
            title = 'Išmesti iš darbo',
            icon = 'fa-solid fa-user-xmark',
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = 'Išmesti darbuotoją?',
                    content = ('Ar tikrai nori atleisti: %s?'):format(member.name),
                    centered = true,
                    cancel = true
                })

                if confirmed == 'confirm' then
                    Send('kick', jobId, { citizenid = member.citizenid })
                    Refresh(jobId)
                end
            end
        }
    end

    if #options == 0 then
        lib.notify({ title = 'Valdymas', description = 'Šiam darbuotojui veiksmų neturi.', type = 'inform' })
        return
    end

    lib.registerContext({
        id = 'grp_jobs_member',
        title = member.name,
        menu = 'grp_jobs_members',
        options = options
    })
    lib.showContext('grp_jobs_member')
end

local function ShowMembers(jobId, data)
    local options = {}

    for _, member in ipairs(data.members) do
        local role = ROLE_LABEL[member.role]

        options[#options + 1] = {
            title = role and ('%s (%s)'):format(member.name, role) or member.name,
            description = ('Rangas: %s%s'):format(
                RankName(data, member.rank),
                member.online and '' or ' · neprisijungęs'
            ),
            icon = 'fa-solid fa-user',
            onSelect = function()
                ShowMember(jobId, data, member)
            end
        }
    end

    if #options == 0 then
        options[1] = { title = 'Darbuotojų dar nėra', disabled = true }
    end

    lib.registerContext({
        id = 'grp_jobs_members',
        title = 'Darbuotojai',
        menu = 'grp_jobs_mgmt',
        options = options
    })
    lib.showContext('grp_jobs_members')
end

local function EditRank(jobId, data, rank)
    local rows = {
        { type = 'input', label = 'Pavadinimas', default = rank.name, required = true, min = 2, max = 32 }
    }

    local vehicleRow, uniformRow

    if #data.models > 0 then
        local choices = {}

        for _, entry in ipairs(data.models) do
            choices[#choices + 1] = { value = entry.model, label = entry.label or entry.model }
        end

        rows[#rows + 1] = {
            type = 'multi-select',
            label = 'Leidžiami transportai (nieko nepasirinkus: visi)',
            options = choices,
            default = rank.vehicles or {}
        }
        vehicleRow = #rows
    end

    if #data.uniforms > 0 then
        local choices = { { value = 'default', label = 'Numatytoji' } }

        for _, key in ipairs(data.uniforms) do
            choices[#choices + 1] = { value = key, label = key }
        end

        rows[#rows + 1] = {
            type = 'select',
            label = 'Apranga',
            options = choices,
            default = rank.uniform or 'default'
        }
        uniformRow = #rows
    end

    local input = lib.inputDialog(('Rangas %d'):format(rank.id), rows)
    if not input then return end

    Send('editRank', jobId, {
        rank = rank.id,
        name = input[1],
        vehicles = vehicleRow and input[vehicleRow] or nil,
        uniform = uniformRow and input[uniformRow] or nil
    })
    Refresh(jobId)
end

local function ShowRanks(jobId, data)
    local options = {}

    for _, rank in ipairs(data.ranks) do
        local vehicles = rank.vehicles and #rank.vehicles > 0
            and ('%d transp.'):format(#rank.vehicles) or 'visi transportai'

        options[#options + 1] = {
            title = ('%d. %s'):format(rank.id, rank.name),
            description = ('%s · apranga: %s'):format(vehicles, rank.uniform or 'numatytoji'),
            icon = 'fa-solid fa-layer-group',
            onSelect = function()
                EditRank(jobId, data, rank)
            end
        }
    end

    if #data.ranks < data.limits.max then
        options[#options + 1] = {
            title = 'Pridėti rangą',
            icon = 'fa-solid fa-plus',
            onSelect = function()
                local input = lib.inputDialog('Naujas rangas', {
                    { type = 'input', label = 'Pavadinimas', required = true, min = 2, max = 32 }
                })

                if input then
                    Send('addRank', jobId, { name = input[1] })
                    Refresh(jobId)
                end
            end
        }
    end

    if #data.ranks > data.limits.min then
        options[#options + 1] = {
            title = 'Pašalinti aukščiausią rangą',
            description = 'Galima tik kai tame range nėra darbuotojų.',
            icon = 'fa-solid fa-minus',
            onSelect = function()
                Send('removeRank', jobId)
                Refresh(jobId)
            end
        }
    end

    lib.registerContext({
        id = 'grp_jobs_ranks',
        title = ('Rangai (%d/%d)'):format(#data.ranks, data.limits.max),
        menu = 'grp_jobs_mgmt',
        options = options
    })
    lib.showContext('grp_jobs_ranks')
end

OpenManagement = function(jobId)
    local data = lib.callback.await('grp_jobs:server:getManagement', false, jobId)

    if not data then return end

    local options = {
        {
            title = 'Darbuotojai',
            description = ('Iš viso: %d'):format(#data.members),
            icon = 'fa-solid fa-users',
            onSelect = function()
                ShowMembers(jobId, data)
            end
        }
    }

    if data.perms.invite then
        options[#options + 1] = {
            title = 'Pakviesti žaidėją',
            description = 'Pakvietimas galioja ribotą laiką. Žaidėjas įsidarbina darbovietėje.',
            icon = 'fa-solid fa-user-plus',
            onSelect = function()
                local input = lib.inputDialog('Pakviesti žaidėją', {
                    { type = 'number', label = 'Žaidėjo ID', required = true, min = 1 }
                })

                if input then
                    Send('invite', jobId, { target = input[1] })
                end
            end
        }
    end

    if data.perms.editRank then
        options[#options + 1] = {
            title = 'Rangai',
            description = ('Rangų skaičius: %d'):format(#data.ranks),
            icon = 'fa-solid fa-layer-group',
            onSelect = function()
                ShowRanks(jobId, data)
            end
        }
    end

    lib.registerContext({
        id = 'grp_jobs_mgmt',
        title = ('%s: valdymas (%s)'):format(data.label, ROLE_LABEL[data.role] or data.role),
        options = options
    })
    lib.showContext('grp_jobs_mgmt')
end

GRPClient.OpenManagement = OpenManagement
