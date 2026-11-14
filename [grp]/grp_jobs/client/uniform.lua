local savedAppearance = nil
local uniformActive = false
local activeUniformJobId = nil
local busy = false

local function Notify(message, kind)
    lib.notify({ title = 'Darbo sistema', description = message, type = kind or 'inform' })
end

-- preset: uniformos rinkinio raktas pagal rangą (cfg.uniforms[preset]); nil = numatytasis
local function GetUniform(cfg, preset)
    local set = cfg.uniform

    if cfg.uniforms then
        set = (preset and cfg.uniforms[preset]) or cfg.uniforms.default or cfg.uniform
    end

    if not set then return nil end

    local model = GetEntityModel(PlayerPedId())
    if model == joaat('mp_m_freemode_01') then
        return set.male
    elseif model == joaat('mp_f_freemode_01') then
        return set.female
    end
    return nil
end

-- Patikrina, ar visi uniformos drabužiai egzistuoja šiam modeliui.
-- Grąžina false ir pirmo blogo elemento aprašą, jei ne.
local function ValidateUniform(ped, uniform)
    for _, item in ipairs(uniform.components or {}) do
        local count = GetNumberOfPedDrawableVariations(ped, item.component_id)
        if item.drawable < 0 or item.drawable >= count then
            return false, ('component %s drawable %s (max %s)')
                :format(item.component_id, item.drawable, count - 1)
        end

        local textures = GetNumberOfPedTextureVariations(
            ped, item.component_id, item.drawable
        )
        if (item.texture or 0) >= textures then
            return false, ('component %s texture %s (max %s)')
                :format(item.component_id, item.texture or 0, textures - 1)
        end
    end

    for _, item in ipairs(uniform.props or {}) do
        -- drawable = -1 reiškia „nuimti daiktą“
        if item.drawable ~= -1 then
            local count = GetNumberOfPedPropDrawableVariations(ped, item.prop_id)
            if item.drawable < 0 or item.drawable >= count then
                return false, ('prop %s drawable %s (max %s)')
                    :format(item.prop_id, item.drawable, count - 1)
            end
        end
    end

    return true
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

local function ApplyUniform(jobId, preset)
    if busy then return false end
    if uniformActive then return false end

    local cfg = Config.Jobs[jobId]
    if not cfg or (not cfg.uniform and not cfg.uniforms) then return false end
    if GetResourceState('illenium-appearance') ~= 'started' then return false end

    local uniform = GetUniform(cfg, preset)
    if not uniform or type(uniform.components) ~= 'table' or #uniform.components == 0 then
        Notify('Šiam veikėjo modeliui nėra darbo uniformos.', 'error')
        return false
    end

    local valid, reason = ValidateUniform(PlayerPedId(), uniform)
    if not valid then
        print(('[GRP JOBS] Netinkama uniforma darbui %s: %s'):format(jobId, reason))
        Notify('Darbo uniforma sukonfigūruota neteisingai. Pranešk administracijai.', 'error')
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

RegisterNetEvent('grp_jobs:client:applyUniform', function(jobId, requestId, preset)
    local success = ApplyUniform(jobId, preset)
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
