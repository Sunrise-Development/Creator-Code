-- client.lua
RegisterNetEvent('creatorcodes:giveWeapon')
AddEventHandler('creatorcodes:giveWeapon', function(weaponName, ammo)
    local playerPed = PlayerPedId()
    if not HasPedGotWeapon(playerPed, GetHashKey(weaponName), false) then
        GiveWeaponToPed(playerPed, GetHashKey(weaponName), ammo or 0, false, false)
    else
        AddAmmoToPed(playerPed, GetHashKey(weaponName), ammo or 0)
    end
end)

-- Optional: keybind to open input box (depends on your input UI)
-- Example: open a simple keyboard input (FiveM native)
RegisterCommand("redeem_ui", function()
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", "", "", "", "", 30)
    local start = GetGameTimer()
    while UpdateOnscreenKeyboard() == 0 do
        Citizen.Wait(0)
        if (GetGameTimer() - start) > 30000 then
            -- timeout
            break
        end
    end
    local result = GetOnscreenKeyboardResult()
    if result and result ~= "" then
        TriggerServerEvent("creatorcodes:redeemRequest", result)
    end
end)

-- Alternate: listen for server chat messages if needed
RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(msg)
    -- you can parse or style messages here
end)
