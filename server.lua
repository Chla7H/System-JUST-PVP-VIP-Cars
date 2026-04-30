local QBCore = exports[Config.CoreName]:GetCoreObject()
local roleCache = {}
local cars = {}
local shopPackages = {}
local purchases = {}
local vault = 0
local settings = {}

local function cloneCar(car)
    return {
        label = tostring(car.label or car.model or 'VIP Car'),
        model = tostring(car.model or ''),
        role = tostring(car.role or Config.Discord.DefaultRoleId or ''),
        image = tostring(car.image or ''),
        description = tostring(car.description or ''),
        cashPrice = math.max(0, math.floor(tonumber(car.cashPrice or car.price) or 0))
    }
end

local function cloneShopPackage(package)
    return {
        id = tostring(package.id or package.label or 'pack'):sub(1, 32),
        label = tostring(package.label or 'Coin Pack'):sub(1, 48),
        coins = math.max(1, math.floor(tonumber(package.coins) or 1)),
        price = math.max(0, math.floor(tonumber(package.price) or 0))
    }
end

local function loadCars()
    local saved = LoadResourceFile(GetCurrentResourceName(), Config.DataFile)
    local decoded = saved and saved ~= '' and json.decode(saved) or nil
    shopPackages = {}
    purchases = {}
    vault = 0
    settings = {
        boostCashPrice = Config.Boost.CashPrice
    }

    if type(decoded) == 'table' and type(decoded.cars) == 'table' then
        cars = {}
        for _, car in ipairs(decoded.cars) do
            cars[#cars + 1] = cloneCar(car)
        end

        if type(decoded.shop) == 'table' and #decoded.shop > 0 then
            for _, package in ipairs(decoded.shop) do
                shopPackages[#shopPackages + 1] = cloneShopPackage(package)
            end
        end

        if #shopPackages == 0 then
            for _, package in ipairs(Config.CoinShop) do
                shopPackages[#shopPackages + 1] = cloneShopPackage(package)
            end
        end

        if type(decoded.purchases) == 'table' then
            purchases = decoded.purchases
        end

        vault = math.max(0, math.floor(tonumber(decoded.vault) or 0))

        if type(decoded.settings) == 'table' then
            settings.boostCashPrice = math.max(0, math.floor(tonumber(decoded.settings.boostCashPrice) or Config.Boost.CashPrice))
        end
        return
    end

    cars = {}
    for _, car in ipairs(Config.Cars) do
        cars[#cars + 1] = cloneCar(car)
    end

    for _, package in ipairs(Config.CoinShop) do
        shopPackages[#shopPackages + 1] = cloneShopPackage(package)
    end
end

local function saveCars()
    SaveResourceFile(GetCurrentResourceName(), Config.DataFile, json.encode({
        cars = cars,
        shop = shopPackages,
        purchases = purchases,
        vault = vault,
        settings = settings
    }), -1)
end

local function getDiscordId(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local discord = identifier:match('discord:(%d+)')
        if discord then
            return discord
        end
    end

    return nil
end

local function hasValue(list, value)
    for _, item in ipairs(list or {}) do
        if tostring(item) == tostring(value) then
            return true
        end
    end

    return false
end

local function fetchDiscordRoles(src, cb)
    local discordId = getDiscordId(src)
    if not discordId then
        cb(false, {}, 'Discord account was not found for this player.')
        return
    end

    local cached = roleCache[discordId]
    if cached and cached.expires > os.time() then
        cb(true, cached.roles)
        return
    end

    if not Config.Discord.BotToken
        or Config.Discord.BotToken == 'PUT_YOUR_DISCORD_BOT_TOKEN_HERE'
        or Config.Discord.BotToken == 'PUT_NEW_DISCORD_BOT_TOKEN_HERE'
    then
        cb(false, {}, 'Discord bot token is missing in config.lua.')
        return
    end

    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(Config.Discord.GuildId, discordId)
    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or not body then
            cb(false, {}, 'Discord API request failed. Status: ' .. tostring(status))
            return
        end

        local data = json.decode(body)
        local roles = data and data.roles or {}
        roleCache[discordId] = {
            roles = roles,
            expires = os.time() + Config.Discord.RoleCacheSeconds
        }

        cb(true, roles)
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. Config.Discord.BotToken,
        ['Content-Type'] = 'application/json'
    })
end

local function getCoins(player)
    return tonumber(player.PlayerData.metadata[Config.Coins.MetadataName]) or 0
end

local function getOwnerKey(player)
    if player and player.PlayerData and player.PlayerData.citizenid then
        return 'citizen:' .. player.PlayerData.citizenid
    end

    return nil
end

local function ownsCar(ownerKey, model)
    return ownerKey and purchases[ownerKey] and purchases[ownerKey][model] == true
end

local function setCarOwned(ownerKey, model)
    if not ownerKey then
        return
    end

    purchases[ownerKey] = purchases[ownerKey] or {}
    purchases[ownerKey][model] = true
end

local function setCoins(player, amount)
    player.Functions.SetMetaData(Config.Coins.MetadataName, math.max(0, math.floor(amount)))
end

local function getCarByModel(model)
    for index, car in ipairs(cars) do
        if car.model == model then
            return car, index
        end
    end

    return nil, nil
end

local function getShopPackage(packageId)
    for index, package in ipairs(shopPackages) do
        if package.id == packageId then
            return package, index
        end
    end

    return nil, nil
end

local function getTargetByInput(input)
    local targetInput = tostring(input or '')
    local targetId = tonumber(targetInput)

    if not targetId then
        for _, src in ipairs(QBCore.Functions.GetPlayers()) do
            if getDiscordId(src) == targetInput then
                targetId = src
                break
            end
        end
    end

    if not targetId then
        return nil, nil
    end

    return QBCore.Functions.GetPlayer(targetId), targetId
end

local function hasPublicSaleCars()
    for _, car in ipairs(cars) do
        if car.cashPrice and car.cashPrice > 0 then
            return true
        end
    end

    return false
end

local function hasAdminRole(roles)
    return Config.Admin.RoleId
        and Config.Admin.RoleId ~= ''
        and hasValue(roles, Config.Admin.RoleId)
end

local function hasAllCarsRole(roles)
    return Config.Access.AllCarsRoleId
        and Config.Access.AllCarsRoleId ~= ''
        and hasValue(roles, Config.Access.AllCarsRoleId)
end

local function hasNoBoostCarsRole(roles)
    return Config.Access.NoBoostCarsRoleId
        and Config.Access.NoBoostCarsRoleId ~= ''
        and hasValue(roles, Config.Access.NoBoostCarsRoleId)
end

local function hasUnlimitedBoostRole(roles)
    return Config.Boost.UnlimitedRoleId
        and Config.Boost.UnlimitedRoleId ~= ''
        and hasValue(roles, Config.Boost.UnlimitedRoleId)
end

local function hasCashBoostRole(roles)
    return Config.Boost.CashRoleId
        and Config.Boost.CashRoleId ~= ''
        and hasValue(roles, Config.Boost.CashRoleId)
end

local function hasCoinBoostRole(roles)
    return Config.Access.MenuRoleId
        and Config.Access.MenuRoleId ~= ''
        and hasValue(roles, Config.Access.MenuRoleId)
end

local function isNoBoostExcluded(model)
    return Config.Access.NoBoostExcludedModels and Config.Access.NoBoostExcludedModels[model] == true
end

local function canUseCar(roles, car, ownerKey)
    if hasAdminRole(roles) or hasAllCarsRole(roles) then
        return true
    end

    if ownsCar(ownerKey, car.model) then
        return true
    end

    if hasNoBoostCarsRole(roles) and not isNoBoostExcluded(car.model) then
        return true
    end

    return hasValue(roles, car.role)
end

local function canOpenMenu(roles)
    if hasAdminRole(roles) or hasAllCarsRole(roles) or hasNoBoostCarsRole(roles) or hasCashBoostRole(roles) then
        return true
    end

    if hasPublicSaleCars() or #shopPackages > 0 then
        return true
    end

    if Config.Access.MenuRoleId and Config.Access.MenuRoleId ~= '' then
        return hasValue(roles, Config.Access.MenuRoleId)
    end

    return true
end

local function makeCarPayload(car, unlocked, includeRole, ownerKey)
    return {
        label = car.label,
        model = car.model,
        role = includeRole and car.role or nil,
        image = car.image,
        description = car.description,
        cashPrice = car.cashPrice,
        forSale = car.cashPrice > 0,
        owned = ownsCar(ownerKey, car.model),
        unlocked = unlocked
    }
end

local function withRoles(source, cb)
    fetchDiscordRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, roles, errorMessage)
            return
        end

        cb(true, roles)
    end)
end

local function validateAdminCar(data)
    local label = tostring(data and data.label or ''):sub(1, 64)
    local model = tostring(data and data.model or ''):sub(1, 64)
    local role = tostring(data and data.role or ''):sub(1, 32)
    local image = tostring(data and data.image or ''):sub(1, 256)
    local description = tostring(data and data.description or ''):sub(1, 180)
    local cashPrice = math.max(0, math.floor(tonumber(data and data.cashPrice) or 0))

    if label == '' then
        return nil, 'Car name is required.'
    end

    if model == '' then
        return nil, 'Spawn model is required.'
    end

    if role == '' and cashPrice <= 0 then
        return nil, 'Discord role ID is required unless the car has a cash price.'
    end

    return {
        label = label,
        model = model,
        role = role,
        image = image,
        description = description,
        cashPrice = cashPrice
    }
end

local function validateShopPackage(data)
    local id = tostring(data and data.id or ''):sub(1, 32)
    local label = tostring(data and data.label or ''):sub(1, 48)
    local coins = math.floor(tonumber(data and data.coins) or 0)
    local price = math.floor(tonumber(data and data.price) or 0)

    if id == '' then
        return nil, 'Package ID is required.'
    end

    if label == '' then
        return nil, 'Package name is required.'
    end

    if coins <= 0 then
        return nil, 'Coin amount must be greater than zero.'
    end

    if price < 0 then
        return nil, 'Price cannot be negative.'
    end

    return cloneShopPackage({ id = id, label = label, coins = coins, price = price })
end

loadCars()

QBCore.Functions.CreateCallback('justpvp_vipcars:server:getMenu', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ ok = false, message = 'Player was not found.', cars = {}, coins = 0 })
        return
    end

    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb({
                ok = false,
                message = errorMessage,
                cars = {},
                coins = getCoins(Player),
                config = Config.Ui
            })
            return
        end

        if not canOpenMenu(roles) then
            cb({
                ok = false,
                message = 'You do not have permission to open this VIP menu.',
                cars = {},
                coins = getCoins(Player),
                config = Config.Ui
            })
            return
        end

        local isAdmin = hasAdminRole(roles)
        local ownerKey = getOwnerKey(Player)
        local payloadCars = {}
        for _, car in ipairs(cars) do
            local unlocked = canUseCar(roles, car, ownerKey)
            if unlocked or isAdmin or car.cashPrice > 0 or not Config.Access.HideLockedCars then
                payloadCars[#payloadCars + 1] = makeCarPayload(car, unlocked, isAdmin, ownerKey)
            end
        end

        cb({
            ok = true,
            cars = payloadCars,
            coins = getCoins(Player),
            player = {
                id = source,
                discord = getDiscordId(source) or 'Not linked'
            },
            shop = shopPackages,
            boostCost = Config.Coins.BoostCost,
            boostCashPrice = settings.boostCashPrice,
            boostCash = hasCashBoostRole(roles) and not hasCoinBoostRole(roles) and not hasUnlimitedBoostRole(roles),
            boostDurationMinutes = Config.Coins.BoostDurationMinutes,
            boostDisabled = hasNoBoostCarsRole(roles) and not hasUnlimitedBoostRole(roles),
            unlimitedBoost = hasUnlimitedBoostRole(roles),
            isAdmin = isAdmin,
            vault = isAdmin and vault or nil,
            config = Config.Ui
        })
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:buyCoins', function(source, cb, packageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 0, 'Player was not found.')
        return
    end

    local package = getShopPackage(tostring(packageId or ''))
    if not package then
        cb(false, getCoins(Player), 'Coin package was not found.')
        return
    end

    local reason = ('vip-car-coins-%s'):format(package.id)
    local paid = Player.Functions.RemoveMoney(Config.Coins.ShopMoneyAccount, package.price, reason)
    if not paid then
        cb(false, getCoins(Player), 'You do not have enough money for this coin package.')
        return
    end

    local coins = getCoins(Player) + package.coins
    setCoins(Player, coins)
    vault = vault + package.price
    saveCars()
    cb(true, coins, ('You bought %s coins.'):format(package.coins))
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:buyCar', function(source, cb, model)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player was not found.')
        return
    end

    local car = getCarByModel(tostring(model or ''))
    if not car then
        cb(false, 'This car is not configured.')
        return
    end

    if car.cashPrice <= 0 then
        cb(false, 'This car is not for sale with cash.')
        return
    end

    local ownerKey = getOwnerKey(Player)
    if ownsCar(ownerKey, car.model) then
        cb(true, 'You already own this car.')
        return
    end

    local paid = Player.Functions.RemoveMoney('cash', car.cashPrice, 'vip-car-purchase-' .. car.model)
    if not paid then
        cb(false, 'You do not have enough cash for this car.')
        return
    end

    setCarOwned(ownerKey, car.model)
    vault = vault + car.cashPrice
    saveCars()
    cb(true, 'Car purchased successfully.')
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:canSpawn', function(source, cb, model)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player was not found.')
        return
    end

    local car = getCarByModel(model)
    if not car then
        cb(false, 'This car is not configured.')
        return
    end

    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not canOpenMenu(roles) then
            cb(false, 'You do not have permission to use this VIP menu.')
            return
        end

        cb(canUseCar(roles, car, getOwnerKey(Player)), 'You do not have the required Discord role or purchase for this car.')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:buyBoost', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 0, 'Player was not found.')
        return
    end

    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, getCoins(Player), errorMessage)
            return
        end

        if hasUnlimitedBoostRole(roles) then
            cb(true, getCoins(Player), 'unlimited')
            return
        end

        if hasCashBoostRole(roles) and not hasCoinBoostRole(roles) then
            local paid = Player.Functions.RemoveMoney(Config.Boost.CashAccount, settings.boostCashPrice, 'vip-car-cash-turbo')
            if not paid then
                cb(false, getCoins(Player), 'You do not have enough cash for turbo.')
                return
            end

            vault = vault + settings.boostCashPrice
            saveCars()

            cb(true, getCoins(Player), 'cash')
            return
        end

        if hasNoBoostCarsRole(roles) then
            cb(false, getCoins(Player), 'Boost is disabled for your VIP role.')
            return
        end

        local coins = getCoins(Player)
        if coins < Config.Coins.BoostCost then
            cb(false, coins, 'You do not have enough coins for turbo.')
            return
        end

        coins = coins - Config.Coins.BoostCost
        setCoins(Player, coins)
        cb(true, coins, 'ok')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminSaveSettings', function(source, cb, data)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        settings.boostCashPrice = math.max(0, math.floor(tonumber(data and data.boostCashPrice) or settings.boostCashPrice))
        saveCars()
        cb(true, 'Settings saved successfully.')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminWithdrawVault', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player was not found.')
        return
    end

    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        if vault <= 0 then
            cb(false, 'The VIP vault is empty.')
            return
        end

        local amount = vault
        vault = 0
        Player.Functions.AddMoney('cash', amount, 'vip-car-vault-withdraw')
        saveCars()
        cb(true, ('You withdrew $%s from the VIP vault.'):format(amount))
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminSaveCar', function(source, cb, data)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local car, validationError = validateAdminCar(data)
        if not car then
            cb(false, validationError)
            return
        end

        local _, index = getCarByModel(car.model)
        if index then
            cars[index] = car
        else
            cars[#cars + 1] = car
        end

        saveCars()
        cb(true, 'Car saved successfully.')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminDeleteCar', function(source, cb, model)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local _, index = getCarByModel(model)
        if not index then
            cb(false, 'Car was not found.')
            return
        end

        table.remove(cars, index)
        saveCars()
        cb(true, 'Car deleted successfully.')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminAddCoins', function(source, cb, data)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local targetInput = tostring(data and data.targetId or '')
        local amount = math.floor(tonumber(data and data.amount) or 0)
        if targetInput == '' or amount == 0 then
            cb(false, 'Target player ID or Discord ID and coin amount are required.')
            return
        end

        local Target, targetId = getTargetByInput(targetInput)
        if not Target then
            cb(false, 'Target player is not online.')
            return
        end

        local coins = getCoins(Target) + amount
        setCoins(Target, coins)
        TriggerClientEvent('justpvp_vipcars:client:coinsUpdated', targetId, coins)
        cb(true, ('Player %s now has %s coins.'):format(targetId, coins))
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminGrantCar', function(source, cb, data)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local targetInput = tostring(data and data.targetId or '')
        local model = tostring(data and data.model or '')
        if targetInput == '' or model == '' then
            cb(false, 'Target player ID or Discord ID and vehicle model are required.')
            return
        end

        local car = getCarByModel(model)
        if not car then
            cb(false, 'This vehicle model is not configured in the VIP panel.')
            return
        end

        local Target, targetId = getTargetByInput(targetInput)
        if not Target then
            cb(false, 'Target player is not online.')
            return
        end

        setCarOwned(getOwnerKey(Target), car.model)
        saveCars()
        cb(true, ('Vehicle %s was granted to player %s.'):format(car.model, targetId))
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminSaveCoinPackage', function(source, cb, data)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local package, validationError = validateShopPackage(data)
        if not package then
            cb(false, validationError)
            return
        end

        local _, index = getShopPackage(package.id)
        if index then
            shopPackages[index] = package
        else
            shopPackages[#shopPackages + 1] = package
        end

        saveCars()
        cb(true, 'Coin package saved successfully.')
    end)
end)

QBCore.Functions.CreateCallback('justpvp_vipcars:server:adminDeleteCoinPackage', function(source, cb, packageId)
    withRoles(source, function(ok, roles, errorMessage)
        if not ok then
            cb(false, errorMessage)
            return
        end

        if not hasAdminRole(roles) then
            cb(false, 'You do not have admin permission for VIP cars.')
            return
        end

        local _, index = getShopPackage(tostring(packageId or ''))
        if not index then
            cb(false, 'Coin package was not found.')
            return
        end

        table.remove(shopPackages, index)
        saveCars()
        cb(true, 'Coin package deleted successfully.')
    end)
end)

CreateThread(function()
    local waitMs = Config.Coins.GiveEveryMinutes * 60 * 1000

    while true do
        Wait(waitMs)

        for _, src in ipairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                setCoins(Player, getCoins(Player) + Config.Coins.GiveAmount)
                TriggerClientEvent('justpvp_vipcars:client:coinsUpdated', src, getCoins(Player))
            end
        end
    end
end)
