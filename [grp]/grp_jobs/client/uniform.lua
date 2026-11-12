local savedAppearance = nil
local uniformActive = false

local appearanceResource = 'illenium-appearance'

local function SaveCurrentOutfit()
    if GetResourceState(appearanceResource) ~= 'started' then
        print('[GRP JOBS] Aprangos sistema neveikia!')
        return false
    end

    local ped = PlayerPedId()

    savedAppearance = exports['illenium-appearance']
        :getPedAppearance(ped)

    return savedAppearance ~= nil
end

local function PutOnBusUniform()
    if uniformActive then return false end

    if not SaveCurrentOutfit() then
        return false
    end

    local ped = PlayerPedId()

    -- Laikina vyriska uniforma testavimui
    if GetEntityModel(ped) ~= joaat('mp_m_freemode_01') then
        print('[GRP JOBS] Siam modeliui uniforma dar nesukurta.')
        savedAppearance = nil
        return false
    end

    local uniform = {
        { component_id = 11, drawable = 13, texture = 0 },
        { component_id = 4, drawable = 10, texture = 0 },
        { component_id = 6, drawable = 10, texture = 0 },
        { component_id = 8, drawable = 15, texture = 0 },
        { component_id = 3, drawable = 15, texture = 0 }
    }

    -- Patikriname, ar drabuziai egzistuoja
    for _, item in ipairs(uniform) do
        local count = GetNumberOfPedDrawableVariations(
            ped, item.component_id
        )

        if item.drawable >= count then
            print('[GRP JOBS] Netinkamas uniformos komponentas!')
            savedAppearance = nil
            return false
        end
    end

    exports['illenium-appearance']:setPedComponents(
        ped, uniform
    )

    uniformActive = true
    return true
end

local function RemoveBusUniform()
    if not uniformActive or not savedAppearance then
        return false
    end

    local ped = PlayerPedId()

    exports['illenium-appearance']:setPedAppearance(
        ped, savedAppearance
    )

    savedAppearance = nil
    uniformActive = false

    return true
end

RegisterNetEvent('grp_jobs:client:changeUniform', function(working)
    local success = false

    if working == true then
        success = PutOnBusUniform()
    elseif working == false then
        success = RemoveBusUniform()
    else
        return
    end

    TriggerServerEvent('grp_jobs:server:uniformResult', working, success)

    if not success then
        TriggerEvent('ox_lib:notify', {
            title = 'Autobusu parkas',
            description = 'Nepavyko pakeisti uniformos.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('grp_jobs:client:restoreClothes', function()
    print('[GRP CLOTHES] Gautas aprangos atkurimo ivykis')

    print('[GRP CLOTHES] Uniforma aktyvi: '
        .. tostring(uniformActive))

    print('[GRP CLOTHES] Apranga issaugota: '
        .. tostring(savedAppearance ~= nil))

    local success = RemoveBusUniform()

    print('[GRP CLOTHES] Atkurimo rezultatas: '
        .. tostring(success))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if not uniformActive or not savedAppearance then
        return
    end

    if GetResourceState('illenium-appearance') ~= 'started' then
        print('[GRP CLOTHES] Aprangos sistema neveikia!')
        return
    end

    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        return
    end

    local success, err = pcall(function()
        exports['illenium-appearance']:setPedAppearance(
            ped,
            savedAppearance
        )
    end)

end)
