-- Core/Events.lua
-- Event registration and handling

local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            Spekifier:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        Spekifier:OnPlayerLogin()
    end
end

-- Set up event handling
Spekifier.frame:SetScript("OnEvent", OnEvent)

-- Register events
Spekifier.frame:RegisterEvent("ADDON_LOADED")
Spekifier.frame:RegisterEvent("PLAYER_LOGIN")

-- Called when the add-on is loaded
function Spekifier:OnAddonLoaded()
    -- Initialize database first
    self:InitializeDatabase()

    self:DebugPrint("Add-on loaded successfully!")
end

-- Called when player logs in
function Spekifier:OnPlayerLogin()
    self:DebugPrint("Welcome,", UnitName("player") .. "!")

    if self.InitializeOptions then self:InitializeOptions() end
    if self.InitializeMinimap then self:InitializeMinimap() end

    -- Create the main window
    self:CreateMainWindow()

    -- Initialize auto-show functionality
    self:InitializeAutoShow()
    if self.InitializeLootSpecialization then self:InitializeLootSpecialization() end

end
