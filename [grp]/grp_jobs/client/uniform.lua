local savedAppearance = nil
local uniformActive = false
local activeUniformJobId = nil
local busy = false

local function Notify(message, kind)
    lib.notify({ title = 'Darbo sistema', description = message, type = kind or 'inform' })
end

local function GetUniform(cfg)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if model == joaat('mp_m_freemode_01') then
        return cfg.uniform and cfg.uniform.male
    elseif model == joaat('mp_f_freemode_01') then
        return cfg.uniform and cfg.uniform.female
    end
    return nil
end

local function RestoreClothes()
    if busy then return false end
    if not uniformActive then
        savedAppearance = nil
        activeUniformJobId = nil
        return true
    end
    if not savedAppearance then return false end
    if GetResourceState('illenium-appearance') ~= 'started' then return false end

    busy = true
    local ok = pcall(function()
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), savedAppearance)
    end)
    busy = false

    if ok then
        uniformActive = false
        savedAppearance = nil
        activeUniformJobId = nil
    end
    return ok
end

local function ApplyUniform(jobId)
    if busy then return false end
    if uniformActive then return false end

    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.uniform then return false end
    if GetResourceState('illenium-appearance') ~= 'started' then return false end

    local uniform = GetUniform(cfg)
    if not uniform or type(uniform.components) ~= 'table' or #uniform.components == 0 then
        Notify('Šiam veikėjo modeliui nėra darbo uniformos.', 'error')
        return false
    end

    busy = true
    local ped = PlayerPedId()
    local ok, appearance = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(ped)
    end)
    if not ok or not appearance then
        busy = false
        return false
    end

    savedAppearance = appearance
    local applied = pcall(function()
        exports['illenium-appearance']:setPedComponents(ped, uniform.components)
        if uniform.props then
            exports['illenium-appearance']:setPedProps(ped, uniform.props)
        end
    end)
    busy = false

    if not applied then
        pcall(function()
            exports['illenium-appearance']:setPedAppearance(ped, appearance)
        end)
        savedAppearance = nil
        return false
    end

    uniformActive = true
    activeUniformJobId = jobId
    return true
end

RegisterNetEvent('grp_jobs:client:applyUniform', function(jobId, requestId)
    local success = ApplyUniform(jobId)
    TriggerServerEvent('grp_jobs:server:uniformResult', jobId, requestId, success)
end)

RegisterNetEvent('grp_jobs:client:restoreClothes', function()
    if not RestoreClothes() then
        Notify('Nepavyko atkurti asmeninės aprangos.', 'error')
    end
end)

-- Jei administratorius / kitas resursas pakeičia darbą – nepaliekame senos uniformos.
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not uniformActive then return end
    local cfg = Config.Jobs[activeUniformJobId]
    if not cfg or not job or job.name ~= cfg.jobName then
        RestoreClothes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    RestoreClothes()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if uniformActive and savedAppearance
        and GetResourceState('illenium-appearance') == 'started' then
        pcall(function()
            exports['illenium-appearance']:setPedAppearance(PlayerPedId(), savedAppearance)
        end)
    end
end)
