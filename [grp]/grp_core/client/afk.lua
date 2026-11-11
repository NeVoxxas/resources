local lastActivity = GetGameTimer()
local isAFK = false

local controls = {
    21, -- Sprintas
    22, -- Sokimas
    24, -- Ataka
    30, -- Judejimas i sonus
    31, -- Judejimas pirmyn / atgal
    38, -- Saveika
    71, -- Automobilio akseleratorius
    72  -- Automobilio stabdziai
}

local function HasActivity()
    if IsPauseMenuActive() then
        return false
    end

    for _, control in ipairs(controls) do
        if IsControlPressed(0, control) then
            return true
        end
    end

    -- Kameros judejimas
    if math.abs(GetControlNormal(0, 1)) > 0.05
        or math.abs(GetControlNormal(0, 2)) > 0.05 then
        return true
    end

    return false
end

CreateThread(function()
    if not Config.AFK or not Config.AFK.Enabled then
        return
    end

    while true do
        Wait(Config.AFK.CheckInterval)

        local now = GetGameTimer()

        if HasActivity() then
            lastActivity = now

            if isAFK then
                isAFK = false

                print('[GRP AFK] Zaidejas vel aktyvus!')

                TriggerServerEvent(
                    'grp_core:server:setAFK',
                    false
                )
            end
        elseif not isAFK
            and now - lastActivity >= Config.AFK.Timeout then

            isAFK = true

            print('[GRP AFK] Zaidejas tapo AFK!')

            TriggerServerEvent(
                'grp_core:server:setAFK',
                true
            )
        end
    end
end)
