local ESX = exports.es_extended:getSharedObject()
local atmOpen = false

local function notify(message, kind)
    lib.notify({ title = 'RS Banking', description = message, type = kind or 'inform' })
end

local function openBank()
    if GetResourceState('rs-economie') ~= 'started' then
        return notify('RS Economie is niet beschikbaar.', 'error')
    end
    exports['rs-economie']:OpenDashboard(false)
end

local function openATM()
    if atmOpen then return end
    lib.callback('rs-banking:server:status', false, function(response)
        if not response or not response.success then
            return notify(response and response.message or 'Automaat niet beschikbaar.', 'error')
        end
        atmOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', payload = response.data })
    end)
end

CreateThread(function()
    exports.ox_target:addModel(Config.ATMModels, {{
        name = 'rs_banking_atm',
        icon = 'fa-solid fa-credit-card',
        label = 'Pinautomaat gebruiken',
        distance = Config.InteractionDistance,
        onSelect = openATM
    }})

    for index, coords in ipairs(Config.BankLocations) do
        exports.ox_target:addSphereZone({
            coords = coords,
            radius = 1.2,
            debug = false,
            options = {{
                name = 'rs_banking_bank_' .. index,
                icon = 'fa-solid fa-building-columns',
                label = 'Bankzaken regelen',
                distance = 2.0,
                onSelect = openBank
            }}
        })
    end
end)

RegisterNUICallback('close', function(_, cb)
    atmOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ success = true })
end)

for _, action in ipairs({ 'setPin', 'login', 'withdraw', 'deposit', 'balance', 'changePin' }) do
    RegisterNUICallback(action, function(data, cb)
        lib.callback('rs-banking:server:' .. action, false, function(response)
            cb(response or { success = false, message = 'Geen antwoord van de server.' })
            if response and response.message then notify(response.message, response.success and 'success' or 'error') end
            if response and response.data then SendNUIMessage({ action = 'update', payload = response.data }) end
        end, data or {})
    end)
end

RegisterNetEvent('rs-banking:client:openBank', openBank)
RegisterNetEvent('rs-banking:client:openATM', openATM)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
