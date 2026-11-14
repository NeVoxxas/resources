GRPJobs = GRPJobs or {}
GRPJobs.Payroll = {}

-- Atlygis kas minutę, kol žaidėjas dirba pamainoje, sėdi savo darbo transporte ir nėra AFK.
-- Suma auga nuo pay.min iki pay.max, kai pay.xpCategory XP pasiekia pay.maxAtXP.
-- (Darbo ir bendrą XP prideda grp_core timeris, žr. rewards.xp.)

local accumulated = {}   -- [src] = sekundės, praleistos transporte nuo paskutinio mokėjimo

function GRPJobs.Payroll.Calc(pay, xp)
    local maxAtXP = pay.maxAtXP or 0
    local ratio = 1

    if maxAtXP > 0 then
        ratio = math.min(math.max((tonumber(xp) or 0) / maxAtXP, 0), 1)
    end

    return math.floor(pay.min + (pay.max - pay.min) * ratio + 0.5)
end

local function PayOnce(src, jobId, pay)
    local xp = exports.grp_core:GetJobXP(src, pay.xpCategory) or 0
    local amount = GRPJobs.Payroll.Calc(pay, xp)

    local paid = exports.qbx_core:AddMoney(src, pay.account or 'bank', amount, 'grp_jobs:' .. jobId)

    if paid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = Config.Jobs[jobId].label,
            description = ('Gavai $%d į banko sąskaitą.'):format(amount),
            type = 'success'
        })
    end

    if Config.Debug then
        print(('[GRP JOBS] %d: atlygis $%d (%s XP %d), sekme: %s')
            :format(src, amount, tostring(pay.xpCategory), xp, tostring(paid)))
    end

    return paid, amount
end

-- Vienas laikmačio žingsnis (kas Config.PayTickSeconds)
function GRPJobs.Payroll.Tick()
    for src, jobId in pairs(GRPJobs.Duty.GetActive()) do
        local cfg = Config.Jobs[jobId]
        local pay = cfg and cfg.rewards and cfg.rewards.pay

        if pay then
            local rec = GRPJobs.Vehicles.Get(src)
            local ped = GetPlayerPed(src)
            local veh = (ped and ped ~= 0) and GetVehiclePedIsIn(ped, false) or 0

            if rec and veh ~= 0 and veh == rec.entity and not exports.grp_core:IsAFK(src) then
                accumulated[src] = (accumulated[src] or 0) + Config.PayTickSeconds

                local interval = pay.everySeconds or 60

                if accumulated[src] >= interval then
                    accumulated[src] = accumulated[src] - interval
                    PayOnce(src, jobId, pay)
                end
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.PayTickSeconds * 1000)
        GRPJobs.Payroll.Tick()
    end
end)

AddEventHandler('grp_jobs:dutyEnded', function(src)
    accumulated[src] = nil
end)

AddEventHandler('playerDropped', function()
    accumulated[source] = nil
end)
