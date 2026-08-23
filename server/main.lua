local ESX = exports.es_extended:getSharedObject()
local sessions = {}

local function response(success, message, data)
    return { success = success, message = message, data = data }
end

local function identifier(xPlayer) return xPlayer and xPlayer.getIdentifier() end
local function bank(xPlayer)
    local account = xPlayer and xPlayer.getAccount('bank')
    return account and math.floor(account.money) or 0
end
local function cash(xPlayer) return xPlayer and math.floor(xPlayer.getMoney()) or 0 end
local function amount(value)
    local parsed = math.floor(tonumber(value) or 0)
    if parsed < 1 or parsed > Config.MaxATMAmount then return nil end
    return parsed
end
local function validPin(pin)
    return type(pin) == 'string' and pin:match('^%d%d%d%d$') ~= nil
end
local function hasCard(source)
    if not Config.RequireBankCard then return true end
    return (exports.ox_inventory:Search(source, 'count', Config.BankCardItem) or 0) > 0
end
local function authenticated(source)
    return sessions[source] and sessions[source] >= os.time()
end
local function snapshot(xPlayer, extra)
    local data = { authenticated = authenticated(xPlayer.source), bank = bank(xPlayer), cash = cash(xPlayer), currency = '€' }
    for key, value in pairs(extra or {}) do data[key] = value end
    return data
end
local function log(event, title, description, xPlayer, level)
    local payload = { resource = GetCurrentResourceName(), event = event, title = title, description = description,
        color = Config.LogColors[level or 'info'], fields = {{ name = 'Speler', value = ('%s\n`%s`'):format(xPlayer.getName(), identifier(xPlayer)) }} }
    if GetResourceState('rs_discordlogs') == 'started' then
        local ok = pcall(function() exports.rs_discordlogs:Log(event, payload) end)
        if ok then return end
    end
    if Config.Webhook ~= '' then PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({ username = 'RS Banking', embeds = { payload } }), { ['Content-Type'] = 'application/json' }) end
end
local function record(xPlayer, kind, mutation, description, metadata)
    if GetResourceState('rs-economie') ~= 'started' then return end
    pcall(function()
        exports['rs-economie']:RecordTransaction(identifier(xPlayer), kind, mutation, description, nil, bank(xPlayer), metadata)
    end)
end

lib.callback.register('rs-banking:server:status', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return response(false, 'Speler niet gevonden.') end
    if not hasCard(source) then return response(false, 'Je hebt geen bankpas bij je.') end
    MySQL.insert.await('INSERT IGNORE INTO rs_banking_security (identifier) VALUES (?)', { identifier(xPlayer) })
    local security = MySQL.single.await('SELECT pin_hash IS NOT NULL AS has_pin, blocked_until FROM rs_banking_security WHERE identifier = ?', { identifier(xPlayer) })
    local blocked = security.blocked_until and os.time() < tonumber(security.blocked_until)
    return response(true, nil, snapshot(xPlayer, { hasPin = security.has_pin == 1 or security.has_pin == true, blocked = blocked, fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:setPin', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local pin = tostring(data.pin or '')
    if not xPlayer or not validPin(pin) then return response(false, 'Kies een pincode van precies vier cijfers.') end
    MySQL.insert.await('INSERT IGNORE INTO rs_banking_security (identifier) VALUES (?)', { identifier(xPlayer) })
    local hasPin = MySQL.scalar.await('SELECT pin_hash IS NOT NULL FROM rs_banking_security WHERE identifier = ?', { identifier(xPlayer) })
    if hasPin == 1 or hasPin == true then return response(false, 'Er is al een pincode ingesteld.') end
    local salt = ('%s:%s:%s'):format(math.random(100000, 999999), os.time(), identifier(xPlayer))
    MySQL.update.await('UPDATE rs_banking_security SET pin_salt = ?, pin_hash = SHA2(CONCAT(?, ?), 256), failed_attempts = 0, blocked_until = NULL WHERE identifier = ?', { salt, pin, salt, identifier(xPlayer) })
    sessions[source] = os.time() + Config.SessionSeconds
    log('pin_created', 'Pincode ingesteld', 'Een nieuwe bankpincode is ingesteld.', xPlayer, 'success')
    return response(true, 'Pincode ingesteld.', snapshot(xPlayer, { authenticated = true, hasPin = true, fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:login', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local pin = tostring(data.pin or '')
    if not xPlayer or not validPin(pin) then return response(false, 'Ongeldige pincode.') end
    local row = MySQL.single.await('SELECT pin_salt, pin_hash, failed_attempts, blocked_until FROM rs_banking_security WHERE identifier = ?', { identifier(xPlayer) })
    if not row or not row.pin_hash then return response(false, 'Stel eerst een pincode in.') end
    if row.blocked_until and os.time() < tonumber(row.blocked_until) then return response(false, 'Je bankpas is tijdelijk geblokkeerd.') end
    local pinMatches = MySQL.scalar.await('SELECT SHA2(CONCAT(?, ?), 256) = ?', { pin, row.pin_salt, row.pin_hash })
    local valid = pinMatches == 1 or pinMatches == true
    if not valid then
        local attempts = (tonumber(row.failed_attempts) or 0) + 1
        local blockUntil = attempts >= Config.MaxPinAttempts and os.time() + Config.BlockMinutes * 60 or nil
        MySQL.update.await('UPDATE rs_banking_security SET failed_attempts = ?, blocked_until = ? WHERE identifier = ?', { attempts, blockUntil, identifier(xPlayer) })
        if blockUntil then log('pin_blocked', 'Bankpas geblokkeerd', 'Te veel onjuiste pincodes.', xPlayer, 'danger') end
        return response(false, blockUntil and ('Te veel pogingen. Geblokkeerd voor %d minuten.'):format(Config.BlockMinutes) or ('Onjuiste pincode. Nog %d poging(en).'):format(Config.MaxPinAttempts - attempts))
    end
    MySQL.update.await('UPDATE rs_banking_security SET failed_attempts = 0, blocked_until = NULL WHERE identifier = ?', { identifier(xPlayer) })
    sessions[source] = os.time() + Config.SessionSeconds
    return response(true, 'Welkom terug.', snapshot(xPlayer, { authenticated = true, hasPin = true, fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:balance', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not authenticated(source) then return response(false, 'Je sessie is verlopen.') end
    return response(true, nil, snapshot(xPlayer, { fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:withdraw', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local value = amount(data.amount)
    if not xPlayer or not authenticated(source) then return response(false, 'Je sessie is verlopen.') end
    if not value then return response(false, 'Ongeldig bedrag.') end
    local fee = math.ceil(value * Config.WithdrawFee / 100)
    if bank(xPlayer) < value + fee then return response(false, 'Onvoldoende banksaldo inclusief transactiekosten.') end
    xPlayer.removeAccountMoney('bank', value + fee, 'RS ATM opname')
    xPlayer.addMoney(value, 'RS ATM opname')
    record(xPlayer, 'atm_withdraw', -(value + fee), 'Contant opgenomen bij pinautomaat', { fee = fee })
    log('atm_withdraw', 'ATM-opname', ('%s nam €%d op (kosten €%d).'):format(xPlayer.getName(), value, fee), xPlayer, 'info')
    return response(true, ('€%d opgenomen. Kosten: €%d.'):format(value, fee), snapshot(xPlayer, { fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:deposit', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local value = amount(data.amount)
    if not xPlayer or not authenticated(source) then return response(false, 'Je sessie is verlopen.') end
    if not value then return response(false, 'Ongeldig bedrag.') end
    if cash(xPlayer) < value then return response(false, 'Je hebt niet genoeg contant geld.') end
    xPlayer.removeMoney(value, 'RS ATM storting')
    xPlayer.addAccountMoney('bank', value, 'RS ATM storting')
    record(xPlayer, 'atm_deposit', value, 'Contant gestort bij pinautomaat')
    log('atm_deposit', 'ATM-storting', ('%s stortte €%d.'):format(xPlayer.getName(), value), xPlayer, 'success')
    return response(true, ('€%d gestort.'):format(value), snapshot(xPlayer, { fee = Config.WithdrawFee }))
end)

lib.callback.register('rs-banking:server:changePin', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local pin = tostring(data.pin or '')
    if not xPlayer or not authenticated(source) then return response(false, 'Je sessie is verlopen.') end
    if not validPin(pin) then return response(false, 'Kies een pincode van precies vier cijfers.') end
    local salt = ('%s:%s:%s'):format(math.random(100000, 999999), os.time(), identifier(xPlayer))
    MySQL.update.await('UPDATE rs_banking_security SET pin_salt = ?, pin_hash = SHA2(CONCAT(?, ?), 256) WHERE identifier = ?', { salt, pin, salt, identifier(xPlayer) })
    sessions[source] = nil
    log('pin_changed', 'Pincode gewijzigd', 'De bankpincode is gewijzigd.', xPlayer, 'info')
    return response(true, 'Pincode gewijzigd. Log opnieuw in.', { authenticated = false, hasPin = true, fee = Config.WithdrawFee })
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
