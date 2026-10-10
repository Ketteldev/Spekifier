-- Saved preferences; visibility belongs only to the current session.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier

function Spekifier:InitializeDatabase()
    if type(SpekifierDB) ~= "table" then SpekifierDB = {} end
    if type(SpekifierDB.settings) ~= "table" then SpekifierDB.settings = {} end
    local defaults = { autoShowMythicPlus = true, autoShowLFR = true, autoShowNormalRaid = true,
        autoShowWorldRaid = true, autoShowHeroicRaid = true, autoShowMythicRaid = true, enabled = true,
        debugEnabled = false, hideMinimapButton = false, minimapAngle = 225 }
    for key, value in pairs(defaults) do
        if SpekifierDB.settings[key] == nil then SpekifierDB.settings[key] = value end
    end
    SpekifierDB.settings.windowShown = nil
    local angle = SpekifierDB.settings.minimapAngle
    if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
        SpekifierDB.settings.minimapAngle = defaults.minimapAngle
    else
        SpekifierDB.settings.minimapAngle = angle % 360
    end
    SpekifierDB.initialized = true
    self.db = SpekifierDB
end

function Spekifier:GetSetting(key)
    if not self.db or not self.db.settings then return nil end
    return self.db.settings[key]
end

function Spekifier:SetSetting(key, value)
    if not self.db or not self.db.settings then return end
    self.db.settings[key] = value
end
