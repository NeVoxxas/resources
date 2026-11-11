
local lastActivity = GetGameTimer()
local isAFK = false

local controls = {
    21, -- Sprint
    22, -- Sokimas
    24, -- Ataka
    30, -- Judejimas i kaire / desine
    31, -- Judejimas pirmyn / atgal
    38, -- Sąveikos mygtukas
    71, -- Automobilio greitejimas
    72  -- Stabdymas
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

    -- Kameros judinimas pele arba pulteliu
    if math.abs(GetControlNormal(0, 1)) > 0.05
        or math.abs(GetControlNormal(0, 2)) > 0.05 then
        return true
    end

    return false
end

CreateThread(function()
    if not Config.AFK.Enabled then return end

    while true do
        Wait(Config.AFK.CheckInterval)

        local now = GetGameTimer()

        if HasActivity() then
            lastActivity = now

            if isAFK then
                isAFK = false
                print('[GRP AFK] Zaidejas vel aktyvus!')
            end
        elseif not isAFK
            and now - lastActivity >= Config.AFK.Timeout then
            isAFK = true
            print('[GRP AFK] Zaidejas tapo AFK!')
        end
    end
end)
