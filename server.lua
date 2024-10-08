QBCore = exports['qb-core']:GetCoreObject()

local civiliansWithBracelets = {}

local function getCivilianId(civilianId)
    if type(civilianId) == 'table' then
        if civilianId.id then
            return civilianId.id
        elseif civilianId.source then
            return civilianId.source
        else
            return nil
        end
    elseif type(civilianId) == 'number' then
        return civilianId
    else
        return nil
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(civilianId)
    local id = getCivilianId(civilianId)
    if not id then return end

    local xPlayer = QBCore.Functions.GetPlayer(id)

    if xPlayer then
        exports.oxmysql:scalar('SELECT bracelet FROM players WHERE citizenid = @citizenid', {
            ['@citizenid'] = xPlayer.PlayerData.citizenid
        }, function(hasBracelet)
            if hasBracelet then
                civiliansWithBracelets[id] = {name = xPlayer.PlayerData.name, coords = nil}
                TriggerClientEvent('qb-bracelet:client:notifyBracelet', id, true)
            end
        end)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local playerId = source
    if civiliansWithBracelets[playerId] then
        TriggerEvent('qb-bracelet:server:removeOfflinePlayer', playerId)
    end
end)

RegisterNetEvent('qb-bracelet:server:removeOfflinePlayer')
AddEventHandler('qb-bracelet:server:removeOfflinePlayer', function(playerId)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end

    exports.oxmysql:execute('UPDATE players SET bracelet = 1 WHERE citizenid = @citizenid', {
        ['@citizenid'] = xPlayer.PlayerData.citizenid
    })

    sendLogToDiscord(playerId, "disconnected with active bracelet")
end)

function sendLogToDiscord(playerId, action)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end

    local webhookURL = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"

    local data = {
        ["username"] = "Bracelet System",
        ["embeds"] = {{
            ["title"] = "Bracelet Log",
            ["description"] = "**Player:** " .. xPlayer.PlayerData.name .. "\n**Action:** " .. action,
            ["color"] = 15158332,
            ["footer"] = {["text"] = os.date("%Y-%m-%d %H:%M:%S")}
        }}
    }

    PerformHttpRequest(webhookURL, function(err, text, headers) end, 'POST', json.encode(data), {['Content-Type'] = 'application/json'})
end

RegisterNetEvent('qb-bracelet:server:toggleBracelet')
AddEventHandler('qb-bracelet:server:toggleBracelet', function(targetPlayer)
    local sourcePlayer = source
    local targetId = tonumber(targetPlayer)

    if type(targetId) ~= 'number' or targetId == sourcePlayer then return end

    local xTargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xTargetPlayer then return end

    if civiliansWithBracelets[targetId] then
        civiliansWithBracelets[targetId] = nil
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', targetId, false)
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', sourcePlayer, false)
        exports.oxmysql:execute('UPDATE players SET bracelet = NULL WHERE citizenid = @citizenid', {
            ['@citizenid'] = xTargetPlayer.PlayerData.citizenid
        })
    else
        civiliansWithBracelets[targetId] = {name = xTargetPlayer.PlayerData.name, coords = nil}
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', targetId, true)
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', sourcePlayer, true)
        exports.oxmysql:execute('UPDATE players SET bracelet = 1 WHERE citizenid = @citizenid', {
            ['@citizenid'] = xTargetPlayer.PlayerData.citizenid
        })
    end
end)

RegisterNetEvent('qb-bracelet:server:applyRemoveBracelet')
AddEventHandler('qb-bracelet:server:applyRemoveBracelet', function(targetId)
    local sourcePlayer = source

    if type(targetId) ~= 'number' or targetId == sourcePlayer then return end

    local xTargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xTargetPlayer then return end

    local xPlayer = QBCore.Functions.GetPlayer(sourcePlayer)
    if xPlayer.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', sourcePlayer, 'You do not have permission to use this!', 'error')
        return
    end

    if civiliansWithBracelets[targetId] then
        civiliansWithBracelets[targetId] = nil
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', targetId, false)
        TriggerClientEvent('QBCore:Notify', sourcePlayer, 'Bracelet removed from civilian.', 'success')
        exports.oxmysql:execute('UPDATE players SET bracelet = NULL WHERE citizenid = @citizenid', {
            ['@citizenid'] = xTargetPlayer.PlayerData.citizenid
        })
    else
        civiliansWithBracelets[targetId] = {name = xTargetPlayer.PlayerData.name, coords = nil}
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', targetId, true)
        TriggerClientEvent('QBCore:Notify', sourcePlayer, 'Bracelet applied to civilian.', 'success')
        exports.oxmysql:execute('UPDATE players SET bracelet = 1 WHERE citizenid = @citizenid', {
            ['@citizenid'] = xTargetPlayer.PlayerData.citizenid
        })
    end
end)

RegisterNetEvent('qb-bracelet:server:removeBracelet')
AddEventHandler('qb-bracelet:server:removeBracelet', function()
    local sourcePlayer = source
    if civiliansWithBracelets[sourcePlayer] then
        civiliansWithBracelets[sourcePlayer] = nil
        TriggerClientEvent('qb-bracelet:client:notifyBracelet', sourcePlayer, false)

        local xPlayer = QBCore.Functions.GetPlayer(sourcePlayer)
        exports.oxmysql:execute('UPDATE players SET bracelet = NULL WHERE citizenid = @citizenid', {
            ['@citizenid'] = xPlayer.PlayerData.citizenid
        })
    end
end)

RegisterNetEvent('qb-bracelet:server:notifyPoliceDeactivation')
AddEventHandler('qb-bracelet:server:notifyPoliceDeactivation', function()
    local sourcePlayer = source
    local xPlayer = QBCore.Functions.GetPlayer(sourcePlayer)

    TriggerClientEvent('QBCore:Notify', -1, "Attempt to deactivate electronic bracelet by " .. xPlayer.PlayerData.name, 'error')
    TriggerClientEvent('qb-bracelet:client:createBlip', -1, GetEntityCoords(GetPlayerPed(sourcePlayer)), xPlayer.PlayerData.name)
end)

QBCore.Commands.Add('testbracelet', 'Activate the electronic bracelet for a specific ID (admin and police only)', {{name = 'id', help = 'Civilian ID'}}, true, function(source, args)
    local adminId = source
    local targetId = tonumber(args[1])

    if not targetId or targetId == adminId or not QBCore.Functions.GetPlayer(targetId) then
        TriggerClientEvent('QBCore:Notify', adminId, 'Invalid civilian or ID not found', 'error')
        return
    end

    local xAdmin = QBCore.Functions.GetPlayer(adminId)
    if not QBCore.Functions.HasPermission(adminId, 'admin') and xAdmin.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', adminId, 'You do not have permission to use this command', 'error')
        return
    end

    TriggerEvent('qb-bracelet:server:toggleBracelet', targetId)
    TriggerClientEvent('QBCore:Notify', adminId, 'Bracelet activated for civilian with ID ' .. targetId, 'success')
end, 'admin')

RegisterNetEvent('qb-bracelet:server:alertPolice')
AddEventHandler('qb-bracelet:server:alertPolice', function(civilianCoords, civilianId)
    local id = getCivilianId(civilianId)
    if not id then return end

    local xPlayer = QBCore.Functions.GetPlayer(id)

    if xPlayer then
        local name = xPlayer.PlayerData.name

        if civiliansWithBracelets[id] then
            TriggerClientEvent('QBCore:Notify', -1, "Civilian with bracelet ("..name..") left the restricted area!", 'error')

            civiliansWithBracelets[id].coords = civilianCoords

            TriggerClientEvent('qb-bracelet:client:createBlip', -1, civilianCoords, name)
        else
            print("[qb-bracelet] Error: Player not found in bracelet table. ID: " .. id)
        end
    end
end)

QBCore.Functions.CreateCallback('qb-bracelet:server:hasBracelet', function(source, cb, targetPlayer)
    local targetId = tonumber(targetPlayer)
    if civiliansWithBracelets[targetId] then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Commands.Add('monitoringpanel', 'Show the monitoring panel for civilians with bracelets', {}, false, function(source)
    local policeId = source

    local xPlayer = QBCore.Functions.GetPlayer(policeId)
    if xPlayer.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', policeId, 'You do not have permission to access the panel.', 'error')
        return
    end

    TriggerClientEvent('qb-bracelet:client:showPanel', policeId, civiliansWithBracelets)
end, 'police')