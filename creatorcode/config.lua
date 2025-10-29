Config = {}

-- Framework "none", "esx", "qb"
Config.Framework = "esx"

-- DB mode: "mysql", or "json"
Config.DB = "mysql"

-- MySQL table name 
Config.MySQLTable = 'creator_codes'

Config.MySQLRedeemTable = 'creator_code_redeems'

-- Admin group
Config.AdminGroups = {"admin", "superadmin"} -- QB/ESX role names or identifiers

-- Redeem command (client & Config)
Config.RedeemCommand = "redeemcode" -- /reedem <CODE>

-- Max code length when auto-generating
Config.DefaultCodeLength = 8 

-- Beispiel Reward-Formate:
-- each reward entry can be {type = "money", amount = 5000}
-- supported types: "money", "bank", "item", "weapon", "command", "job"
-- for item: {type="item", name="bread", count=2}
-- for weapon: {type="weapon", name="weapon_pistol", ammo=50}
-- for command: {type="command", command="givevip %player%"}

Config.PredefinedCodes = {
    ["WELCOME10"] = {
        uses = 100, -- number of times the Code can be used total (nil or 0 = unlimited)
        expires = nil, -- timestamp in seconds when it expires (nil = never)
        rewards = {
            {type = "money", amount = 1000},
            {type = "item", name = "water", count = 1},
        },
        creator = "system",
        multi = true -- whether the same player can redeem multiple times (false = one per player)    
    },
    ["SINGLEGIFT"] = {
        uses = 1,
        expires = nil,
        rewards = {
            {type = "item", name = "phone", count = 1}
        },
        creator = "admin",
        multi = false
    }
}