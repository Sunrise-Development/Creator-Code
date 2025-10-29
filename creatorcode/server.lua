-- server.lua
local codes = {}
local playerRedeems = {} -- track per-player redemptions when multi=false
local jsonFile = "creator_codes_store.json"

-- load/save helpers for JSON fallback
local function loadJson()
    if Config.DB ~= "json" then return end
    local path = GetResourcePath(GetCurrentResourceName()) .. "/" .. jsonFile
    local f = io.open(path, "r")
    if f then
        local data = f:read("*a")
        f:close()
        local ok, obj = pcall(function() return json.decode(data) end)
        if ok and type(obj) == "table" then
            codes = obj.codes or {}
            playerRedeems = obj.playerRedeems or {}
        end
    else
        codes = Config.PredefinedCodes or {}
        playerRedeems = {}
        saveJson()
    end
end

function saveJson()
    if Config.DB ~= "json" then return end
    local path = GetResourcePath(GetCurrentResourceName()) .. "/" .. jsonFile
    local f = io.open(path, "w+")
    if f then
        local obj = { codes = codes, playerRedeems = playerRedeems }
        f:write(json.encode(obj))
        f:close()
    end
end

local function fetchFromMySQL(callback)
    -- Prüfen, ob MySQL aktiv ist
    if not Config.DB or Config.DB:lower() ~= "mysql" then
        print("[CreatorCode] ⚠️ MySQL ist in der Config deaktiviert oder falsch konfiguriert.")
        callback(false)
        return
    end

    -- Sicherstellen, dass die Tabelle definiert ist
    if not Config.MySQLTable or Config.MySQLTable == "" then
        print("[CreatorCode] ❌ Fehler: 'Config.MySQLTable' ist nicht gesetzt! Bitte in der config.lua definieren.")
        callback(false)
        return
    end

    -- Daten aus der Tabelle laden
    local query = ("SELECT code, data FROM %s"):format(Config.MySQLTable)
    exports.oxmysql:execute(query, {}, function(rows)
        if not rows or #rows == 0 then
            print("[CreatorCode] ⚠️ Keine Creator Codes in der Datenbank gefunden.")
            callback(false)
            return
        end

        codes = {}
        for _, r in ipairs(rows) do
            local ok, data = pcall(json.decode, r.data)
            if ok and data then
                codes[r.code] = data
            else
                print(("[CreatorCode] ⚠️ Fehler beim Laden von Code '%s' (ungültiges JSON)."):format(r.code or "unbekannt"))
            end
        end

        print(("[CreatorCode] ✅ %s Creator Codes erfolgreich aus der Datenbank geladen."):format(#rows))
        callback(true)
    end)
end

local function saveCodeToMySQL(code, data)
    if Config.DB ~= "mysql" then return end
    local jsonData = json.encode(data)
    exports.oxmysql:execute("REPLACE INTO "..Config.MySQLTable.." (code, data) VALUES (?, ?)", {code, jsonData})
end

local function deleteCodeFromMySQL(code)
    if Config.DB ~= "mysql" then return end
    exports.oxmysql:execute("DELETE FROM "..Config.MySQLTable.." WHERE code = ?", {code})
end

-- Utility: Check admin (supports qb/esx/basic identifiers)
local function isAdmin(source)
    if Config.Framework == "qb" then
        local Player = QBCore and QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        local groups = Config.AdminGroups
        local isAdmin = false
        for _, g in ipairs(groups) do
            if Player.PlayerData.job and Player.PlayerData.job.name == g then
                isAdmin = true
            end
        end
        -- You may prefer to check permissions differently (cfx exports or ACE)
        return isAdmin
    elseif Config.Framework == "esx" then
        local xPlayer = ESX and ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        for _, g in ipairs(Config.AdminGroups) do
            if xPlayer.getGroup and xPlayer.getGroup() == g then return true end
        end
        return false
    else
        -- fallback check: player with steam identifier? or everyone false
        return false
    end
end

-- apply rewards
local function giveRewards(source, rewards)
    local identifier = nil
    if Config.Framework == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        identifier = Player and Player.PlayerData.citizenid
    elseif Config.Framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier
    end

    for _, r in ipairs(rewards) do
        if r.type == "money" then
            if Config.Framework == "qb" then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player and r.amount then Player.Functions.AddMoney("cash", r.amount) end
            elseif Config.Framework == "esx" then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer and r.amount then xPlayer.addMoney(r.amount) end
            end
        elseif r.type == "bank" then
            if Config.Framework == "qb" then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player and r.amount then Player.Functions.AddMoney("bank", r.amount) end
            elseif Config.Framework == "esx" then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer and r.amount then xPlayer.addAccountMoney('bank', r.amount) end
            end
        elseif r.type == "item" then
            if Config.Framework == "qb" then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then Player.Functions.AddItem(r.name, r.count or 1) end
            elseif Config.Framework == "esx" then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then xPlayer.addInventoryItem(r.name, r.count or 1) end
            end
        elseif r.type == "weapon" then
            if Config.Framework == "qb" then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then Player.Functions.AddItem(r.name, 1) end -- or use GiveWeapon
                -- Optionally give ammo using client event
                TriggerClientEvent('creatorcodes:giveWeapon', source, r.name, r.ammo or 0)
            elseif Config.Framework == "esx" then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then
                    TriggerClientEvent('creatorcodes:giveWeapon', source, r.name, r.ammo or 0)
                end
            end
        elseif r.type == "command" then
            local cmd = r.command:gsub("%%player%%", source)
            ExecuteCommand(cmd)
        elseif r.type == "job" then
            if Config.Framework == "qb" then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then Player.Functions.SetJob(r.job, r.grade or 0) end
            elseif Config.Framework == "esx" then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then xPlayer.setJob(r.job, r.grade or 0) end
            end
        end
    end
end

-- Redeem logic
local function redeemCode(source, code)
    local _src = source
    local identifier = nil
    if Config.Framework == "qb" then
        local Player = QBCore and QBCore.Functions.GetPlayer(_src)
        identifier = Player and Player.PlayerData.citizenid
    elseif Config.Framework == "esx" then
        local xPlayer = ESX and ESX.GetPlayerFromId(_src)
        identifier = xPlayer and xPlayer.identifier
    else
        -- fallback: use source string
        identifier = tostring(_src)
    end

    local entry = codes[code]
    if not entry then
        TriggerClientEvent('chat:addMessage', _src, { args = {"CreatorCode", "Ungültiger Code."}})
        return
    end

    -- check expiration
    if entry.expires and entry.expires > 0 and os.time() > entry.expires then
        TriggerClientEvent('chat:addMessage', _src, { args = {"CreatorCode", "Dieser Code ist abgelaufen."}})
        return
    end

    -- check total uses
    if entry.uses and entry.uses > 0 then
        if entry.uses <= 0 then
            TriggerClientEvent('chat:addMessage', _src, { args = {"CreatorCode", "Dieser Code wurde bereits vollständig eingelöst."}})
            return
        end
    end

    -- check per-player usage if multi == false
    if entry.multi == false then
        playerRedeems[identifier] = playerRedeems[identifier] or {}
        if playerRedeems[identifier][code] then
            TriggerClientEvent('chat:addMessage', _src, { args = {"CreatorCode", "Du hast diesen Code bereits eingelöst."}})
            return
        end
    end

    -- grant rewards
    giveRewards(_src, entry.rewards or {})

    -- mark used
    if entry.uses and entry.uses > 0 then
        entry.uses = entry.uses - 1
        if entry.uses <= 0 then
            codes[code] = nil
            if Config.DB == "json" then saveJson() end
            if Config.DB == "mysql" then deleteCodeFromMySQL(code) end
        else
            if Config.DB == "json" then saveJson() end
            if Config.DB == "mysql" then saveCodeToMySQL(code, entry) end
        end
    else
        if Config.DB == "json" then saveJson() end
        if Config.DB == "mysql" then saveCodeToMySQL(code, entry) end
    end

    if entry.multi == false then
        playerRedeems[identifier] = playerRedeems[identifier] or {}
        playerRedeems[identifier][code] = true
        if Config.DB == "json" then saveJson() end
    end

    TriggerClientEvent('chat:addMessage', _src, { args = {"CreatorCode", "Code erfolgreich eingelöst!"} })
end

RegisterNetEvent("creatorcodes:redeemRequest")
AddEventHandler("creatorcodes:redeemRequest", function(code)
    local src = source
    if not code then return end
    redeemCode(src, tostring(code):upper())
end)

-- Commands
RegisterCommand(Config.RedeemCommand, function(source, args, raw)
    local code = args[1]
    if not code then
        TriggerClientEvent('chat:addMessage', source, { args = {"CreatorCode", "Nutze: /"..Config.RedeemCommand.." <CODE>"} })
        return
    end
    code = tostring(code):upper()
    redeemCode(source, code)
end, false)

-- Admin create command: /createcode CODE USES MULTI EXPIRES_JSON reward_json
-- Example: /createcode MYCODE 10 true 0 {"rewards":[{"type":"money","amount":5000}]}
RegisterCommand("createcode", function(source, args, raw)
    if source ~= 0 and not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = {"CreatorCode", "Keine Berechtigung."} })
        return
    end
    local code = args[1]
    if not code then
        print("Usage: createcode <CODE> <uses> <multi> <expires_ts> <rewards_json>")
        return
    end
    code = tostring(code):upper()
    local uses = tonumber(args[2]) or 0
    local multi = args[3] == "true"
    local expires = tonumber(args[4]) or nil
    local rewards_raw = args[5]
    local rewards = {}
    if rewards_raw then
        --  join rest of args to allow complex json
        local rest = {}
        for i=5,#args do rest[#rest+1]=args[i] end
        local j = table.concat(rest, " ")
        local ok, parsed = pcall(function() return json.decode(j) end)
        if ok and parsed and parsed.rewards then rewards = parsed.rewards end
    end

    codes[code] = {
        uses = uses,
        expires = expires,
        rewards = rewards,
        creator = "admin",
        multi = multi
    }

    if Config.DB == "json" then saveJson() end
    if Config.DB == "mysql" then saveCodeToMySQL(code, codes[code]) end

    print("Code created: "..code)
end, true)

-- Admin delete code
RegisterCommand("deletecode", function(source, args, raw)
    if source ~= 0 and not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = {"CreatorCode", "Keine Berechtigung."} })
        return
    end
    local code = args[1]
    if not code then return end
    code = tostring(code):upper()
    codes[code] = nil
    if Config.DB == "json" then saveJson() end
    if Config.DB == "mysql" then deleteCodeFromMySQL(code) end
    print("Code deleted: "..code)
end, true)

-- On resource start: load data
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Config.DB == "json" then loadJson() end
    if Config.DB == "mysql" then fetchFromMySQL(function(ok) if not ok then print("Failed to load codes from MySQL") end end) end
end)

-- Export for other resources
exports('RedeemCode', function(source, code) redeemCode(source, tostring(code):upper()) end)
