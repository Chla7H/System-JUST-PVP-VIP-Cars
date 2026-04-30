local QBCore = exports[Config.CoreName]:GetCoreObject()
local menuOpen = false
local boostActive = false
local lastVehicle = nil

local function notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or 'primary')
end

local function isPlayerDead()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) or GetEntityHealth(ped) <= 0 then
        return true
    end

    local playerData = QBCore.Functions.GetPlayerData()
    local metadata = playerData and playerData.metadata or {}
    if metadata.isdead or metadata.inlaststand or metadata.dead or metadata.laststand then
        return true
    end

    local state = LocalPlayer and LocalPlayer.state
    if state and (state.isdead or state.inlaststand or state.dead or state.laststand) then
        return true
    end

    return false
end

local function hasActiveVipVehicle()
    return lastVehicle and DoesEntityExist(lastVehicle)
end

local function deleteLastVipVehicle()
    if not hasActiveVipVehicle() then
        lastVehicle = nil
        return
    end

    NetworkRequestControlOfEntity(lastVehicle)
    local timeout = GetGameTimer() + 1500
    while DoesEntityExist(lastVehicle) and not NetworkHasControlOfEntity(lastVehicle) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(lastVehicle)
    end

    SetEntityAsMissionEntity(lastVehicle, true, true)
    DeleteVehicle(lastVehicle)
    DeleteEntity(lastVehicle)
    lastVehicle = nil
end

local function openMenu(force)
    if menuOpen and not force then
        return
    end

    if Config.Access.RequireAliveToOpen and isPlayerDead() then
        notify('You cannot open VIP cars while dead.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:getMenu', function(data)
        if Config.Access.RequireAliveToOpen and isPlayerDead() then
            notify('You cannot open VIP cars while dead.', 'error')
            return
        end

        if not data or not data.ok then
            local message = data and data.message or 'access_denied'
            notify(tostring(message), 'error')
            return
        end

        menuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            payload = data
        })
    end)
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function applyBoost(vehicle, unlimited)
    if not vehicle or vehicle == 0 or boostActive then
        return
    end

    boostActive = true
    local endAt = unlimited and nil or GetGameTimer() + (Config.Coins.BoostDurationMinutes * 60 * 1000)

    CreateThread(function()
        while boostActive and DoesEntityExist(vehicle) and (unlimited or GetGameTimer() < endAt) do
            SetVehicleEnginePowerMultiplier(vehicle, Config.Boost.EnginePowerMultiplier)
            SetVehicleEngineTorqueMultiplier(vehicle, Config.Boost.EngineTorqueMultiplier)
            Wait(1000)
        end

        if DoesEntityExist(vehicle) then
            SetVehicleEnginePowerMultiplier(vehicle, 0.0)
            SetVehicleEngineTorqueMultiplier(vehicle, 1.0)
        end

        boostActive = false
        notify('Turbo has ended.', 'primary')
    end)
end

RegisterCommand(Config.Command, function()
    openMenu(false)
end, false)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('spawnCar', function(data, cb)
    local model = data and data.model
    if not model then
        cb({ ok = false })
        return
    end

    if Config.Access.RequireAliveToOpen and isPlayerDead() then
        notify('You cannot spawn VIP cars while dead.', 'error')
        cb({ ok = false, reason = 'dead' })
        return
    end

    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:canSpawn', function(canSpawn, reason)
        if not canSpawn then
            notify(tostring(reason or 'You cannot spawn this car.'), 'error')
            cb({ ok = false, reason = reason })
            return
        end

        closeMenu()

        if Config.Spawn.ReplaceOldVehicle or Config.Spawn.DeleteOldVehicle then
            deleteLastVipVehicle()
        end

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        QBCore.Functions.SpawnVehicle(model, function(vehicle)
            lastVehicle = vehicle
            SetEntityHeading(vehicle, heading)
            SetVehicleOnGroundProperly(vehicle)
            SetVehicleDirtLevel(vehicle, 0.0)
            SetVehicleNumberPlateText(vehicle, 'JUSTPVP')
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))

            if Config.Spawn.WarpIntoVehicle then
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
            end

            notify('VIP car spawned.', 'success')
        end, coords, true)

        cb({ ok = true })
    end, model)
end)

RegisterNUICallback('buyCar', function(data, cb)
    local model = data and data.model
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:buyCar', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, model)
end)

RegisterNUICallback('buyBoost', function(_, cb)
    if Config.Access.RequireAliveToOpen and isPlayerDead() then
        notify('You cannot use turbo while dead.', 'error')
        cb({ ok = false, reason = 'dead' })
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('You must be the driver of a vehicle.', 'error')
        cb({ ok = false, reason = 'not_driver' })
        return
    end

    if boostActive then
        notify('Turbo is already active.', 'error')
        cb({ ok = false, reason = 'already_active' })
        return
    end

    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:buyBoost', function(ok, coins, reason)
        if not ok then
            notify(tostring(reason or 'Turbo is not available.'), 'error')
            cb({ ok = false, coins = coins, reason = reason })
            return
        end

        applyBoost(vehicle, reason == 'unlimited')
        if reason == 'unlimited' then
            notify('Turbo max is active with no time limit.', 'success')
        elseif reason == 'cash' then
            notify(('Turbo is active for %s minutes. Paid with cash.'):format(Config.Coins.BoostDurationMinutes), 'success')
        else
            notify(('Turbo is active for %s minutes.'):format(Config.Coins.BoostDurationMinutes), 'success')
        end
        SendNUIMessage({ action = 'coins', coins = coins })
        cb({ ok = true, coins = coins })
    end)
end)

RegisterNUICallback('buyCoins', function(data, cb)
    local packageId = data and data.id
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:buyCoins', function(ok, coins, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            SendNUIMessage({ action = 'coins', coins = coins })
        end
        cb({ ok = ok, coins = coins, message = message })
    end, packageId)
end)

RegisterNUICallback('adminSaveCar', function(data, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminSaveCar', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, data)
end)

RegisterNUICallback('adminDeleteCar', function(data, cb)
    local model = data and data.model
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminDeleteCar', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, model)
end)

RegisterNUICallback('adminAddCoins', function(data, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminAddCoins', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        cb({ ok = ok, message = message })
    end, data)
end)

RegisterNUICallback('adminGrantCar', function(data, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminGrantCar', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        cb({ ok = ok, message = message })
    end, data)
end)

RegisterNUICallback('adminSaveCoinPackage', function(data, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminSaveCoinPackage', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, data)
end)

RegisterNUICallback('adminDeleteCoinPackage', function(data, cb)
    local packageId = data and data.id
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminDeleteCoinPackage', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, packageId)
end)

RegisterNUICallback('adminSaveSettings', function(data, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminSaveSettings', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end, data)
end)

RegisterNUICallback('adminWithdrawVault', function(_, cb)
    QBCore.Functions.TriggerCallback('justpvp_vipcars:server:adminWithdrawVault', function(ok, message)
        notify(tostring(message), ok and 'success' or 'error')
        if ok then
            openMenu(true)
        end
        cb({ ok = ok, message = message })
    end)
end)

RegisterNetEvent('justpvp_vipcars:client:coinsUpdated', function(coins)
    SendNUIMessage({ action = 'coins', coins = coins })
end)

RegisterKeyMapping(Config.Command, 'Open VIP cars menu', 'keyboard', 'F7')
