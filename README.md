# System-JUST-PVP-VIP-Cars

QBCore FiveM resource for `/carvip`.

## Features

- Discord role check with guild `0000000000000000000`
- Every VIP car has its own editable Discord role id in `config.lua`
- Cars without the player's Discord role are hidden from the menu
- The VIP menu only opens for players with the main VIP role
- Role `0000000000000000000` opens all cars and gets unlimited max boost
- Role `0000000000000000000` is also the in-game VIP cars admin role
- Admins can add, edit, and delete cars from the panel with image URL, role ID, model, name, and description
- Admin changes are saved in `data/cars.json`
- Players can buy VIP coins from the Coin Shop tab with in-game cash
- Admins can add coins to online players by player ID or Discord ID
- Admins can change coin shop packages and prices from the panel
- Admins can set a cash turbo price from the panel
- Admins can put cars on sale for cash without requiring a Discord role
- Cash from coin packs, cash turbo, and cash car sales goes into the VIP vault
- Admins can withdraw the VIP vault from the panel
- Role `0000000000000000000` opens cars without boost, except `Mor`
- Role `0000000000000000000` can open the panel for cash turbo only. VIP cars stay hidden unless the player has car roles too.
- Dead players cannot open the VIP car menu or spawn cars
- Spawning a new VIP car deletes the old VIP car directly
- Pink NUI panel for JUST PVP
- Online players receive 15 VIP coins every 5 minutes
- Turbo boost costs 100 coins and lasts 3 minutes

## Install

1. Put `justpvp_vipcars` inside your FiveM `resources` folder.
2. Add this to `server.cfg`:

```cfg
ensure justpvp_vipcars
```

3. Open `config.lua` and set:

```lua
Config.Discord.BotToken = 'YOUR_BOT_TOKEN'
```

Do not share your bot token. If it was posted anywhere, reset it in Discord Developer Portal and use the new one.

4. In Discord Developer Portal, enable these bot intents:

- Server Members Intent
- Message Content Intent is not required for this script

5. Invite the bot to your Discord server and make sure the bot can read members.

## Change car roles

Every car has a `role` field:

```lua
{ label = 'Car 1', model = 'Neam Car', role = '0000000000000000000' }
```

Change only the `role` id if every car should need a different Discord role.

## Notes

- Players must have Discord connected to FiveM.
- The logo URL from Imgur album may not render inside NUI. If it does not show, upload a direct image link ending in `.png`, `.jpg`, or `.webp` and put it in `Config.Ui.LogoUrl`.
- Coin metadata key is `vipcarcoins`.
- Set `Config.Access.MenuRoleId` to the main role required for `/carvip` and F7.
- Set `Config.Spawn.ReplaceOldVehicle = false` if you do not want new VIP cars to delete the old one.
- Set `Config.Access.HideLockedCars = false` if you want locked cars to appear in the menu.
