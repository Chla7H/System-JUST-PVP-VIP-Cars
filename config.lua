Config = {}

Config.CoreName = 'qb-core'
Config.Command = 'carvip'
Config.DataFile = 'data/cars.json'

Config.Discord = {
    GuildId = 'GuildId',
    BotToken = 'YOUR_BOT_TOKEN',
    RoleCacheSeconds = 3,
    DefaultRoleId = 'Default_Role_Id'
}

Config.Coins = {
    MetadataName = 'vipcarcoins',
    GiveEveryMinutes = 5,
    GiveAmount = 15,
    BoostCost = 100,
    BoostDurationMinutes = 3,
    ShopMoneyAccount = 'cash'
}

Config.CoinShop = {
    { id = 'small', label = 'Small Pack', coins = 100, price = 50000 },
    { id = 'medium', label = 'Medium Pack', coins = 250, price = 100000 },
    { id = 'large', label = 'Large Pack', coins = 600, price = 200000 }
}

Config.Access = {
    HideLockedCars = true,
    RequireAliveToOpen = true,
    MenuRoleId = '0000000000000000000',
    AllCarsRoleId = '0000000000000000000',
    NoBoostCarsRoleId = '0000000000000000000',
    NoBoostExcludedModels = {
        Mor = true
    }
}

Config.Admin = {
    RoleId = '0000000000000000000'
}

Config.Boost = {
    EnginePowerMultiplier = 45.0,
    EngineTorqueMultiplier = 2.0,
    UnlimitedRoleId = '0000000000000000000',
    CashRoleId = '0000000000000000000',
    CashPrice = 75000,
    CashAccount = 'cash'
}

Config.Spawn = {
    WarpIntoVehicle = true,
    DeleteOldVehicle = true,
    ReplaceOldVehicle = true
}

Config.Ui = {
    ServerName = 'Server_Name',
    LogoUrl = 'https://r2.fivemanage.com/bAXUTGhcXGgKc1K2JzAjd/icon.gif'
}

Config.Cars = {
    { label = 'Car 1', model = 'Neam Car', role = '0000000000000000000' },
    { label = 'Car 1', model = 'Neam Car', role = '0000000000000000000' },
    { label = 'Car 1', model = 'Neam Car', role = '0000000000000000000' },
}
