local QBCore = exports['qb-core']:GetCoreObject()
local hasBracelet = false
local braceletObj = nil
local warned = false

AddEventHandler('playerDropped', function(reason)
    if hasBracelet then
        TriggerServerEvent('qb-bracelet:server:removeOfflinePlayer', GetPlayerServerId(PlayerId()))
    end
end)

RegisterNetEvent('qb-bracelet:client:applyRemoveBracelet')
AddEventHandler('qb-bracelet:client:applyRemoveBracelet', function(targetPlayer)
    local ped = PlayerPedId()
    local targetId = tonumber(targetPlayer)

    if targetId == GetPlayerServerId(PlayerId()) then
        QBCore.Functions.Notify('You cannot use this on yourself!', 'error')
        return
    end

    loadAnimDict("mp_arresting")
    TaskPlayAnim(ped, "mp_arresting", "a_uncuff", 8.0, 8.0, -1, 49, 0, 0, 0, 0)
    Citizen.Wait(2000)
    ClearPedTasks(ped)

    TriggerServerEvent('qb-bracelet:server:applyRemoveBracelet', targetId)
end)

RegisterNetEvent('qb-bracelet:client:removeBraceletIllegally')
AddEventHandler('qb-bracelet:client:removeBraceletIllegally', function()
    if hasBracelet then
        local successChance = math.random(1, 100)
        QBCore.Functions.Progressbar("remove_bracelet", "Trying to remove the bracelet...", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "mp_arresting",
            anim = "a_uncuff",
            flags = 49,
        }, {}, {}, function()
            ClearPedTasks(PlayerPedId())

            if successChance <= 30 then
                QBCore.Functions.Notify('You successfully deactivated the bracelet!', 'success')
                TriggerServerEvent('qb-bracelet:server:removeBracelet')
            else
                QBCore.Functions.Notify('Deactivation attempt failed! The police have been notified.', 'error')
                TriggerServerEvent('qb-bracelet:server:notifyPoliceDeactivation')
            end
        end, function()
            ClearPedTasks(PlayerPedId())
            QBCore.Functions.Notify('You failed to remove the bracelet.', 'error')
        end)
    else
        QBCore.Functions.Notify('You do not have a bracelet to remove.', 'error')
    end
end)

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(100)
    end
end

RegisterNetEvent('qb-bracelet:client:notifyBracelet')
AddEventHandler('qb-bracelet:client:notifyBracelet', function(state)
    hasBracelet = state
    warned = false

    if state then
        QBCore.Functions.Notify('You received an electronic bracelet! Stay in the center of Los Santos.', 'success')
        attachBraceletToAnkle()
    else
        QBCore.Functions.Notify('Your electronic bracelet has been removed.', 'error')
        removeBracelet()
    end
end)

function attachBraceletToAnkle()
    local playerPed = PlayerPedId()
    local boneIndex = GetPedBoneIndex(playerPed, 0xF9BB)

    local isMale = IsPedModel(playerPed, GetHashKey("mp_m_freemode_01"))
    local objectModel

    if isMale then
        objectModel = "mp_m_freemode_01^teef_011_u"
        RequestModel("mp_m_freemode_01^teef_diff_011_a_uni")
    else
        objectModel = "mp_f_freemode_01^teef_008_u"
        RequestModel("mp_f_freemode_01^teef_diff_008_a_uni")
    end

    RequestModel(objectModel)

    while not HasModelLoaded(objectModel) do
        Citizen.Wait(100)
    end

    braceletObj = CreateObject(GetHashKey(objectModel), 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(braceletObj, playerPed, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
end

function removeBracelet()
    if braceletObj then
        DeleteObject(braceletObj)
        braceletObj = nil
    end
end

RegisterNetEvent('qb-bracelet:client:createBlip')
AddEventHandler('qb-bracelet:client:createBlip', function(coords, name)
    if QBCore.Functions.GetPlayerData().job.name == 'police' then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Bracelet Deactivation Attempt: " .. name)
        EndTextCommandSetBlipName(blip)
        Citizen.Wait(10000)
        RemoveBlip(blip)
    end
end)

Citizen.CreateThread(function()
    local centerLosSantos = vector3(177.12, -823.93, 31.18)
    local maxDistance = 500.0

    while true do
        Citizen.Wait(5000)

        if hasBracelet then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - centerLosSantos)

            if distance > maxDistance and not warned then
                warned = true
                QBCore.Functions.Notify('You are leaving the allowed area! Return immediately!', 'error')
                TriggerServerEvent('qb-bracelet:server:alertPolice', playerCoords, GetPlayerServerId(PlayerId()))

                Citizen.CreateThread(function()
                    for i = 1, 3 do
                        Citizen.Wait(30000)

                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local distance = #(playerCoords - centerLosSantos)
                        if distance > maxDistance then
                            QBCore.Functions.Notify('You are leaving the allowed area! Return immediately!', 'error')
                            TriggerServerEvent('qb-bracelet:server:alertPolice', playerCoords, GetPlayerServerId(PlayerId()))
                        else
                            warned = false
                            break
                        end
                    end
                end)
            elseif distance <= maxDistance then
                warned = false
            end
        end
    end
end)

RegisterCommand('braceletStatus', function()
    if hasBracelet then
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "showStatus",
            status = "active"
        })
    else
        QBCore.Functions.Notify('You do not have an electronic bracelet.', 'error')
    end
end)

RegisterNUICallback('closeStatus', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)