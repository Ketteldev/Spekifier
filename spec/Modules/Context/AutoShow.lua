-- Run from the repository root: lua spec/Modules/Context/AutoShow.lua
-- Uses the production database, window, columns, commands and event modules.
local originalPrint = print
local checks = 0
local function expect(value, label)
    assert(value, label)
    checks = checks + 1
end
local function fixture(overrides, saved)
    local state = { inInstance = true, instanceType = "raid", exists = true,
        attackable = true, dead = false, classification = "worldboss",
        level = -1, combat = false, targetReads = 0, difficultyID = 14, instanceID = 2912, npcID = 240435, name = "Test Dungeon", difficultyName = "Difficulty" }
    for key, value in pairs(overrides or {}) do state[key] = value end
    local frames = {}
    state.messages, state.timers, state.mapRequests = {}, {}, 0
    function print(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        state.messages[#state.messages + 1] = table.concat(parts, " ")
    end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) state.messages[#state.messages + 1] = text end }
    function strjoin(separator, ...) return table.concat({ ... }, separator) end
    C_Timer = { After = function(_, callback)
        state.timers[#state.timers + 1] = callback
    end }
    function state:Tick()
        local pending = self.timers
        self.timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
    C_MythicPlus = { RequestMapInfo = function()
        state.mapRequests = state.mapRequests + 1
    end }

    UISpecialFrames, SlashCmdList, SpekifierDB = {}, {}, saved
    UIParent = { GetWidth = function() return state.uiWidth or 1000 end,
        GetHeight = function() return state.uiHeight or 800 end }
    function CreateFrame(_, name, parent, template)
        local frame = { scripts = {}, hooks = {}, events = {}, shown = true,
            registrations = 0, bindings = 0, showCount = 0, alpha = 1 }
        function frame:RegisterEvent(event)
            self.events[event] = true
            self.registrations = self.registrations + 1
        end
        function frame:SetScript(key, fn)
            self.scripts[key] = fn
            self.bindings = self.bindings + 1
        end
        function frame:HookScript(key, fn)
            self.hooks[key] = self.hooks[key] or {}
            table.insert(self.hooks[key], fn)
            self.bindings = self.bindings + 1
        end
        function frame:Fire(key, ...)
            if self.scripts[key] then self.scripts[key](self, ...) end
            for _, fn in ipairs(self.hooks[key] or {}) do fn(self, ...) end
        end
        function frame:Show()
            if self.shown then return end
            self.shown = true
            self.showCount = self.showCount + 1
            self:Fire("OnShow")
        end
        function frame:Hide()
            if not self.shown then return end
            self.shown = false
            self:Fire("OnHide")
        end
        function frame:IsShown() return self.shown end
        function frame:GetFont() return "Fonts/FRIZQT__.TTF", self.fontSize or 12, "" end
        function frame:SetFont(font, size, flags) self.fontSize = size end
        function frame:SetEnabled(value) self.enabled = not not value end
        function frame:IsEnabled() return self.enabled ~= false end
        function frame:SetChecked(value) self.checked = not not value end
        function frame:GetChecked() return self.checked end
        function frame:SetText(text) self.text = text end
        function frame:SetAlpha(alpha) self.alpha = alpha end
        function frame:EnableMouse(enabled) self.mouseEnabled = enabled end
        function frame:CreateFontString() return CreateFrame() end
        function frame:CreateTexture() return CreateFrame() end
        for _, method in ipairs({ "SetSize", "SetPoint", "SetMovable", "RegisterForDrag",
            "StartMoving", "StopMovingOrSizing", "SetFrameStrata", "SetWidth",
            "SetAllPoints", "SetClampedToScreen", "SetHeight", "SetWordWrap",
            "SetJustifyH", "SetTextColor", "SetHighlightTexture", "RegisterForClicks", "EnableMouseWheel",
            "SetScrollChild", "SetThumbTexture", "SetOrientation", "SetValueStep", "SetObeyStepOnDrag" }) do
            frame[method] = function() end
        end
        function frame:SetSize(width, height) self.width, self.height = width, height end
        function frame:SetFrameStrata(strata) self.strata = strata end
        function frame:SetFrameLevel(level) self.level = level end
        function frame:GetFrameLevel() return self.level or 100 end
        function frame:GetWidth() return self.width end
        function frame:GetHeight() return self.height end
        function frame:ClearAllPoints() self.point = nil end
        function frame:SetScale(scale) self.scale = scale end
        function frame:SetWidth(width) self.width = width end
        function frame:SetHeight(height) self.height = height end
        function frame:SetPoint(...) self.point = { ... } end
        function frame:SetColorTexture(...) self.color = { ... } end
        function frame:SetTexture(texture) self.texture = texture end
        function frame:IsMouseOver() return self.mouseOver or false end
        function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
        function frame:SetVerticalScroll(value) self.scrollOffset = value end
        function frame:SetHorizontalScroll(value) self.horizontalOffset = value end
        function frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
        function frame:SetValue(value)
            if self.value == value then return end
            self.value = value
            self:Fire("OnValueChanged", value)
        end
        if state.skins then
            function frame:SetResizable(value) self.resizable = value end
            function frame:SetResizeBounds(...) self.resizeBounds = { ... } end
            function frame:StartSizing(corner) self.sizing = corner end
            function frame:SetRotation(value) self.rotation = value end
            function frame:SetNormalTexture(value) self.normalTexture = value end
            function frame:SetPushedTexture(value) self.pushedTexture = value end
            function frame:GetNormalTexture() return self.normalRegion end
            function frame:GetPushedTexture() return self.pushedRegion end
            function frame:SetTextColor(...) self.textColor = { ... } end
            if template == "BasicFrameTemplateWithInset" then
                for _, region in ipairs({ "Bg", "TitleBg", "TopBorder", "BottomBorder", "LeftBorder", "RightBorder", "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "BotLeftCorner", "BotRightCorner", "TopTileStreaks", "Inset", "InsetBg", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight", "CloseButton" }) do frame[region] = CreateFrame() end
                frame.CloseButton.normalRegion = CreateFrame()
                frame.CloseButton.pushedRegion = CreateFrame()
            end
            function frame:SetSize(width, height)
                local changed = self.width ~= width or self.height ~= height
                self.width, self.height = width, height
                if changed then self:Fire("OnSizeChanged", width, height) end
            end
        end
        if name then _G[name] = frame end
        frames[#frames + 1] = frame
        return frame
    end
    function IsInInstance() return state.inInstance, state.instanceType end
    function GetInstanceInfo()
        return state.name, state.instanceType, state.difficultyID, state.difficultyName, 5, 0, false, state.instanceID
    end
    function InCombatLockdown() return state.combat end
    local function readTarget()
        assert(not state.combat, "target API read during combat")
        state.targetReads = state.targetReads + 1
    end
    function UnitExists() readTarget(); return state.exists end
    function UnitCanAttack() readTarget(); return state.attackable end
    function UnitIsDeadOrGhost() readTarget(); return state.dead end
    function UnitClassification() readTarget(); return state.classification end
    function UnitLevel() readTarget(); return state.level end
    function UnitGUID()
        readTarget()
        if state.noGUID then return nil end
        return state.guid or ("Creature-0-1-2912-1-" .. state.npcID .. "-00000001")
    end
    function issecretvalue(value) return state.secretGUID and value == state.guid end
    C_EncounterJournal = { GetInstanceForGameMap = function(mapID)
        if state.noJournal then return nil end
        return state.journalID or (mapID == 2657 and 1273 or 1307)
    end }
    for _, api in ipairs({ "EJ_SelectInstance", "EJ_SelectEncounter", "EJ_SetDifficulty",
        "EJ_SetLootFilter", "EJ_SetSearch", "EncounterJournal_LoadUI" }) do
        _G[api] = function() error("resolver must not mutate/open Journal: " .. api) end
    end
    function EJ_GetEncounterInfo(id)
        if state.noEncounter then return nil end
        return "Localized Boss " .. id, nil, state.returnedEncounterID or id, nil, nil,
            state.encounterJournalID or (state.instanceID == 2657 and 1273 or 1307),
            nil, state.encounterMapID or state.instanceID
    end
    C_ChallengeMode = {
        GetMapTable = function() return state.challengeMaps or { 501, 502, 503 } end,
        GetMapUIInfo = function(id)
            if state.missingMapInfo then return nil end
            local maps = state.challengeGameMaps or { [501] = 2912, [502] = 100, [503] = 200 }
            return "Localized Dungeon", id, 1800, nil, 0, maps[id]
        end,
    }
    function UnitName() return "Tester" end
    function GetNumSpecializations() return state.numSpecs or 3 end
    function GetSpecializationInfo(i) return i, "Spec " .. i, nil, i end
    local namespace = {}
    assert(loadfile("src/Core/Init.lua"))("Spekifier", namespace)
    local addon = namespace.Spekifier
    assert(loadfile("src/Core/Debug.lua"))("Spekifier", namespace)
    function addon:Print(text) self.message = text end
    for _, file in ipairs({
        "src/Core/Database.lua",
        "src/Core/Events.lua",
        "src/Modules/Loot/RequestIdentity.lua",
        "src/UI/Window/Lifecycle.lua",
        "src/UI/Window/LootBinding.lua",
        "src/Modules/Loot/Diagnostics.lua",
        "src/UI/Window/Fit.lua",
        "src/UI/Loot/Tooltips.lua",
        "src/UI/Loot/DisplayLists.lua",
        "src/UI/Loot/SharedRow.lua",
        "src/UI/Loot/ItemRows.lua",
        "src/UI/Loot/Columns.lua",
        "src/UI/Loot/Renderer.lua",
        "src/Modules/Context/RaidCatalog.lua",
        "src/Modules/Context/Resolver.lua",
        "src/Modules/Commands.lua",
        "src/Modules/Context/AutoShow.lua",
    }) do
        assert(loadfile(file))("Spekifier", namespace)
    end
    if state.selectionModule then
        function GetLootSpecialization() return state.lootSpec or 1 end
        function GetSpecialization() return state.activeSpec or 1 end
        function SetLootSpecialization(id) state.lootSpec = id end
        assert(loadfile("src/Modules/Loot/Selection.lua"))("Spekifier", namespace)
    end
    if state.discovery then
        Minimap = CreateFrame()
        Minimap:SetSize(140, 140)
        function Minimap:GetCenter() return 100, 100 end
        function Minimap:GetEffectiveScale() return state.minimapScale or 1 end
        function GetCursorPosition() return state.cursorX or 200, state.cursorY or 100 end
        function GetMinimapShape() return state.minimapShape or "ROUND" end
        state.categories, state.openedCategories = {}, {}
        Settings = {
            RegisterCanvasLayoutCategory = function(panel, name)
                local category = { panel = panel, name = name }
                function category:GetID() return 42 end
                return category
            end,
            RegisterAddOnCategory = function(category) table.insert(state.categories, category) end,
            OpenToCategory = function(id)
                if state.settingsError then error("mock client restriction") end
                table.insert(state.openedCategories, id)
            end,
        }
        GameTooltip = { lines = {} }
        function GameTooltip:SetOwner(owner) self.owner = owner end
        function GameTooltip:IsOwned(owner) return self.owner == owner end
        function GameTooltip:SetText(text) self.text = text; self.lines = {} end
        function GameTooltip:AddLine(text) table.insert(self.lines, text) end
        function GameTooltip:Show() self.shown = true end
        function GameTooltip:Hide() self.shown = false; self.owner = nil end
        for _, file in ipairs({ "src/UI/Options/Panel.lua", "src/UI/Minimap.lua" }) do
            assert(loadfile(file))("Spekifier", namespace)
        end
    end
    if state.skins then
        C_AddOns = { IsAddOnLoaded = function(name) local loaded = state.loadedAddons and state.loadedAddons[name] or false; return loaded, loaded end }
        function UIDropDownMenu_SetWidth(d, width) d.width = width end
        function UIDropDownMenu_SetText(d, text) d.text = text end
        function UIDropDownMenu_CreateInfo() return {} end
        function UIDropDownMenu_AddButton(info) state.menu[#state.menu + 1] = info end
        function UIDropDownMenu_Initialize(d, callback) d.initialize = callback end
        state.menu = {}
        for _, file in ipairs({
            "src/UI/Skins/Registry.lua",
            "src/UI/Skins/Palettes.lua",
            "src/UI/Skins/Presentation.lua",
            "src/UI/Options/SkinDropdown.lua",
            "src/UI/Window/Layout.lua",
        }) do
            assert(loadfile(file))("Spekifier", namespace)
        end
    end
    addon:InitializeDatabase()
    if state.skins and state.startupAddon then
        state.loadedAddons = state.loadedAddons or {}
        state.loadedAddons[state.startupAddon] = true
    end
    addon:OnPlayerLogin()
    local function event(name, unit) addon.autoShowFrame:Fire("OnEvent", name, unit) end
    return addon, state, event, frames
end

local cases = {
    { "ordinary trash", { classification = "normal", level = 80, npcID = 999 }, false },
    { "elite trash", { classification = "elite", level = 80, npcID = 999 }, false },
    { "missing target", { exists = false }, false },
    { "friendly boss", { attackable = false }, false },
    { "dead boss", { dead = true }, false },
    { "dungeon boss", { instanceType = "party" }, false },
    { "outdoor boss", { inInstance = false, instanceType = "none" }, false },
    { "known boss without skull level", { classification = "normal", level = 80 }, true },
    { "unknown skull-level target", { classification = "elite", npcID = 999 }, false },
    { "login in combat", { combat = true }, false },
}
for _, case in ipairs(cases) do
    local addon = fixture(case[2])
    expect(addon:GetMainWindow():IsShown() == case[3], case[1])
end

local addon = fixture(nil, { initialized = true, settings = {
    enabled = false, windowShown = true, custom = "preserved" } })
expect(not addon:GetMainWindow():IsShown(), "disabled and saved visibility cannot open")
expect(addon.db.settings.enabled == false and addon.db.settings.debugEnabled == false,
    "merge missing defaults without overwriting false")
expect(addon.db.settings.windowShown == nil and addon.db.settings.custom == "preserved",
    "remove legacy visibility and preserve unrelated preference")
addon:InitializeDatabase()
expect(addon.db.settings.enabled == false, "repeat migration preserves settings")
for _, saved in ipairs({ { initialized = true }, { settings = false }, { settings = {
    enabled = false, debugEnabled = true } } }) do
    local migrated = fixture({ exists = false }, saved)
    expect(type(migrated.db.settings) == "table" and migrated:GetSetting("enabled") ~= nil,
        "missing or malformed settings repaired")
    if saved.settings.debugEnabled then
        expect(migrated:GetSetting("debugEnabled"), "debug preference preserved")
    end
end
addon = fixture({ inInstance = false }, { settings = { windowShown = true } })
expect(not addon:GetMainWindow():IsShown(), "reload outside raid never restores popup")

for _, close in ipairs({ "button", "escape", "slash" }) do
    local a, state, event = fixture()
    local window, runtime = a:GetMainWindow(), a:GetWindowState()
    local key = runtime.contextKey
    if close == "button" then
        window:Hide() -- template close button hides directly
    elseif close == "escape" then
        _G[UISpecialFrames[1]]:Hide() -- Escape's registered-frame path
    else
        SlashCmdList.SPEKIFIER("toggle")
    end
    expect(not window:IsShown() and runtime.openingReason == nil and
        runtime.lastCloseReason == "dismissed" and runtime.dismissedContextKey == key,
        close .. " synchronizes dismissal")
    expect(runtime.contextKey == nil and not runtime.selectionAllowed, close .. " clears context")
    for _, refresh in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UNIT_HEALTH" }) do
        event(refresh, "target")
        expect(not window:IsShown(), close .. " suppresses unrelated refresh " .. refresh)
    end
    a:InitializeAutoShow()
    expect(not window:IsShown(), "reinitialization does not clear dismissal")
    state.exists = false
    event("PLAYER_TARGET_CHANGED")
    state.exists = true
    event("PLAYER_TARGET_CHANGED")
    expect(window:IsShown() and runtime.contextKey ~= key, close .. " retarget permits prompt")
    expect(a.db.settings.windowShown == nil, "visibility never persisted")
end

local a, state, event, frames = fixture()
local window, runtime = a:GetMainWindow(), a:GetWindowState()
local key = runtime.contextKey
window.encounterData = { loot = "old" }
event("PLAYER_TARGET_CHANGED")
expect(window:IsShown() and runtime.contextKey ~= key and window.encounterData == nil,
    "boss switch clears previous display immediately")
local shows = window.showCount
event("UNIT_HEALTH", "player")
expect(window.showCount == shows, "unrelated unit event ignored")
state.dead = true
event("UNIT_HEALTH", "target")
expect(not window:IsShown() and runtime.contextKey == nil and runtime.lastCloseReason == "invalid-context",
    "boss death hides automatic window without target change")
state.dead = false
event("UNIT_HEALTH", "target")
expect(window:IsShown(), "programmatic hide does not dismiss")
state.attackable = false
event("UNIT_FACTION", "target")
expect(not window:IsShown(), "friendly target hides")
state.attackable = true
event("UNIT_FLAGS", "target")
state.inInstance = false
event("ZONE_CHANGED_NEW_AREA")
expect(not window:IsShown(), "leaving raid hides automatic window")

for _, wasDismissed in ipairs({ false, true }) do
    a, state, event = fixture()
    window, runtime = a:GetMainWindow(), a:GetWindowState()
    if wasDismissed then window:Hide() end
    state.targetReads = 0
    event("PLAYER_REGEN_DISABLED") -- authoritative before lockdown changes
    expect(not window:IsShown() and state.targetReads == 0, "combat entry hides without target reads")
    state.combat = true
    event("PLAYER_TARGET_CHANGED")
    SlashCmdList.SPEKIFIER("toggle")
    expect(not window:IsShown() and state.targetReads == 0 and a.message ~= nil,
        "combat prevents manual opening and target reads")
    state.combat = false
    event("PLAYER_REGEN_ENABLED")
    expect(window:IsShown() and runtime.openingReason == "automatic", "wipe permits fresh prompt")
end

a, state, event = fixture({ inInstance = false })
SlashCmdList.SPEKIFIER("t")
window, runtime = a:GetMainWindow(), a:GetWindowState()
expect(window:IsShown() and runtime.openingReason == "manual" and runtime.contextKey == nil,
    "manual preview outside raid")
expect(window.status.text:find("Preview") and not runtime.selectionAllowed, "explanatory disabled preview")
for _, column in pairs(a:GetAllSpecColumns()) do
    expect(column.frame.icon.alpha == 1 and column.visualState == "disabled", "preview columns disabled")
end
state.inInstance = true
event("ZONE_CHANGED_NEW_AREA")
expect(runtime.contextKey ~= nil and runtime.openingReason == "manual", "manual ownership retained")
window.encounterData = { old = true }
state.exists = false
event("PLAYER_TARGET_CHANGED")
expect(window:IsShown() and window.encounterData == nil and runtime.contextKey == nil,
    "manual invalid context stays open with cleared display")
event("PLAYER_REGEN_DISABLED")
expect(not window:IsShown() and runtime.openingReason == nil, "combat hides manual preview")

a, state, event = fixture(nil, { settings = { enabled = false } })
SlashCmdList.SPEKIFIER("toggle")
expect(a:GetMainWindow():IsShown(), "manual preview available when auto-show disabled")
a:GetMainWindow():Hide()
a:SetSetting("enabled", true)
event("UNIT_HEALTH", "target")
expect(not a:GetMainWindow():IsShown(), "manual dismissal suppresses automatic reopening")
event("PLAYER_TARGET_CHANGED")
expect(a:GetMainWindow():IsShown(), "changing target clears manual dismissal")
a:SetSetting("enabled", false)
event("UNIT_HEALTH", "target")
expect(not a:GetMainWindow():IsShown(), "disabled setting closes automatic window")

a, state, event, frames = fixture()
local frameCount, bindings, registrations = #frames, a.autoShowFrame.bindings, a.autoShowFrame.registrations
local windowBindings = a:GetMainWindow().bindings
a:OnPlayerLogin()
a:CreateMainWindow()
a:InitializeAutoShow()
expect(#frames == frameCount and a.autoShowFrame.bindings == bindings and
    a.autoShowFrame.registrations == registrations and a:GetMainWindow().bindings == windowBindings,
    "repeat initialization has no duplicate frames or handlers")
expect(#UISpecialFrames == 1, "Escape registration unique")
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION",
    "UNIT_CLASSIFICATION_CHANGED" }) do
    expect(a.autoShowFrame.events[name], "registered lifecycle event " .. name)
end


-- Dungeon entry is independent of all target APIs and current target state.
for _, difficulty in ipairs({ 1, 2, 8, 23 }) do
    a, state, event = fixture({ instanceType = "party", difficultyID = difficulty, exists = false })
    window = a:GetMainWindow()
    expect(window:IsShown() == (difficulty == 8 or difficulty == 23), "dungeon difficulty " .. difficulty)
    expect(state.targetReads == 0, "dungeon eligibility never reads target")
end

for _, close in ipairs({ "button", "escape", "slash", "combat" }) do
    a, state, event = fixture({ instanceType = "party", difficultyID = 23, exists = false })
    window, runtime = a:GetMainWindow(), a:GetWindowState()
    key = runtime.contextKey
    expect(runtime.contextKind == "dungeon" and runtime.dungeonContext.lootMode == "mythic-plus",
        "explicit dungeon context and intended loot mode")
    expect(window.header.text:find(": Mythic%+") and not runtime.selectionAllowed,
        "ordinary Mythic clearly previews Mythic+ with selection gated")
    for _, refresh in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_TARGET_CHANGED", "UNIT_HEALTH", "CHALLENGE_MODE_START" }) do
        event(refresh, "target")
        expect(window:IsShown() and runtime.contextKey == key and window.showCount == 1,
            "visible dungeon survives duplicate and target event " .. refresh)
    end
    if close == "button" then window:Hide()
    elseif close == "escape" then _G[UISpecialFrames[1]]:Hide()
    elseif close == "slash" then SlashCmdList.SPEKIFIER("toggle")
    else event("PLAYER_REGEN_DISABLED") end
    expect(not window:IsShown() and runtime.contextKey == nil, "dungeon close clears display " .. close)
    if close ~= "combat" then expect(runtime.dismissedContextKey == key, "visit dismissal recorded") end
    state.difficultyID = 8
    for _, refresh in ipairs({ "CHALLENGE_MODE_START", "PLAYER_DIFFICULTY_CHANGED",
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "CHALLENGE_MODE_RESET" }) do
        event(refresh, "target")
        expect(not window:IsShown(), "consumed visit never reopens on " .. refresh)
    end
    a:InitializeAutoShow()
    expect(not window:IsShown(), "repeat initialization retains dungeon prompt")
    state.inInstance = false
    event("ZONE_CHANGED_NEW_AREA")
    state.inInstance = true
    event("PLAYER_ENTERING_WORLD")
    expect(window:IsShown() and runtime.contextKey ~= key, "exit reentry prompts new visit")
end

-- Deferred entry belongs only to the eligible visit that survives combat.
for _, transition in ipairs({ "same", "exit", "heroic", "different" }) do
    a, state, event = fixture({ instanceType = "party", difficultyID = 23, combat = true })
    window = a:GetMainWindow()
    expect(not window:IsShown() and not a:GetAutoShowState().dungeonVisit.prompted,
        "entry in combat defers unconsumed prompt")
    local originalVisit = a:GetAutoShowState().dungeonVisit.visitID
    if transition == "exit" then state.inInstance = false
    elseif transition == "heroic" then state.difficultyID = 2
    elseif transition == "different" then state.instanceID = 200 end
    event("ZONE_CHANGED_NEW_AREA")
    state.combat = false
    event("PLAYER_REGEN_ENABLED")
    expect(window:IsShown() == (transition == "same" or transition == "different"),
        "combat deferred transition " .. transition)
    if transition == "different" then
        expect(a:GetAutoShowState().dungeonVisit.visitID ~= originalVisit, "different dungeon gets own deferred visit")
    end
end

-- Fresh fixture models a new Lua session on login/reload, with saved visibility ignored.
for _, difficulty in ipairs({ 8, 23 }) do
    a = fixture({ instanceType = "party", difficultyID = difficulty, exists = false },
        { settings = { windowShown = false } })
    expect(a:GetMainWindow():IsShown(), "login reload evaluates dungeon fresh " .. difficulty)
end

a, state, event = fixture({ instanceType = "party", difficultyID = 23 },
    { settings = { enabled = false } })
window, runtime = a:GetMainWindow(), a:GetWindowState()
expect(not window:IsShown(), "disabled setting prevents dungeon auto prompt")
SlashCmdList.SPEKIFIER("toggle")
expect(window:IsShown() and runtime.contextKind == "dungeon" and runtime.openingReason == "manual",
    "disabled automatic opening permits dungeon manual preview")
window:Hide()
a:SetSetting("enabled", true)
event("PLAYER_TARGET_CHANGED")
event("CHALLENGE_MODE_START")
expect(not window:IsShown(), "manual preview consumes dungeon prompt even while disabled")
SlashCmdList.SPEKIFIER("toggle")
expect(window:IsShown(), "consumed prompt does not block explicit manual preview")
window.encounterData = { old = true }
state.difficultyID = 8
event("PLAYER_DIFFICULTY_CHANGED")
expect(window:IsShown() and window.encounterData == nil and runtime.difficultyID == 8,
    "key start invalidates difficulty data without closing valid manual context")
window.encounterData = { old = true }
state.difficultyID = 2
event("PLAYER_DIFFICULTY_CHANGED")
expect(window:IsShown() and runtime.contextKey == nil and window.encounterData == nil and
    window.status.text:find("Preview"), "manual ineligible dungeon shows empty state")

-- Eligibility changes and direct dungeon switches immediately discard obsolete display.
a, state, event = fixture({ instanceType = "party", difficultyID = 23 })
window, runtime = a:GetMainWindow(), a:GetWindowState()
key = runtime.contextKey
window.encounterData = { old = true }
state.instanceID = 200
event("ZONE_CHANGED_NEW_AREA")
expect(window:IsShown() and runtime.contextKey ~= key and window.encounterData == nil,
    "direct dungeon identity change replaces context")
event("PLAYER_REGEN_DISABLED")
event("PLAYER_REGEN_ENABLED")
expect(not window:IsShown(), "visible context replacement consumes new visit prompt")

for _, difficulty in ipairs({ 1, 2 }) do
    a, state, event = fixture({ instanceType = "party", difficultyID = 23 })
    window = a:GetMainWindow()
    state.difficultyID = difficulty
    event("PLAYER_DIFFICULTY_CHANGED")
    expect(not window:IsShown(), "difficulty ineligibility hides automatic window")
    state.difficultyID = 23
    event("PLAYER_DIFFICULTY_CHANGED")
    expect(window:IsShown(), "new eligible interval permits prompt")
end

for _, name in ipairs({ "PLAYER_DIFFICULTY_CHANGED", "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET" }) do
    expect(a.autoShowFrame.events[name], "registered dungeon lifecycle event " .. name)
end
-- Manual dungeon previews also close on physical exit.
a, state, event = fixture({ instanceType = "party", difficultyID = 23 },
    { settings = { enabled = false } })
a:ShowWindow("manual")
state.inInstance = false
event("ZONE_CHANGED_NEW_AREA")
expect(not a:GetMainWindow():IsShown() and a:GetWindowState().dungeonContext == nil,
    "manual dungeon exit hides and clears data")

-- A disabled, unshown visit remains available if automation is enabled later.
a, state, event = fixture({ instanceType = "party", difficultyID = 23 },
    { settings = { enabled = false } })
a:SetSetting("enabled", true)
event("PLAYER_ENTERING_WORLD")
expect(a:GetMainWindow():IsShown(), "enabling automation allows unconsumed entry")
expect(not a:GetAutoShowState().canPrompt, "prompt permission consumed immediately")
a, state, event = fixture({ instanceType = "party", difficultyID = 23, instanceID = 0 })
expect(not a:GetMainWindow():IsShown(), "missing dungeon identity fails closed")
state.instanceID = 100
event("PLAYER_ENTERING_WORLD")
expect(a:GetMainWindow():IsShown(), "delayed instance identity permits entry evaluation")
window, runtime = a:GetMainWindow(), a:GetWindowState()
key = runtime.contextKey
for _, change in ipairs({ "dead", "friendly", "trash", "cleared" }) do
    if change == "dead" then state.dead = true
    elseif change == "friendly" then state.attackable = false
    elseif change == "trash" then state.classification, state.level = "normal", 80
    else state.exists = false end
    event("PLAYER_TARGET_CHANGED")
    event("UNIT_HEALTH", "target")
    expect(window:IsShown() and runtime.contextKey == key, "dungeon survives target becoming " .. change)
end
window.encounterData = { old = true }
state.difficultyID = 8
event("CHALLENGE_MODE_START")
expect(window:IsShown() and runtime.contextKey == key and window.showCount == 1 and
    window.encounterData == nil, "automatic keystone transition clears data without another prompt")
state.instanceType = "raid"
state.difficultyID = 14
state.instanceID = 2912
state.exists, state.attackable, state.dead = true, true, false
state.classification, state.level = "worldboss", -1
event("ZONE_CHANGED_NEW_AREA")
expect(window:IsShown() and runtime.contextKind == "raid", "dungeon to raid resumes raid context")
window:Hide()
event("PLAYER_REGEN_DISABLED")
event("PLAYER_REGEN_ENABLED")
expect(window:IsShown(), "raid wipe reset still works after dungeon dismissal")
-- Phase 3 acceptance and fail-closed identity checks.
for _, npc in ipairs({ 240435, 240434, 250892, 254109, 240432,
    250589, 250588, 250587, 244761 }) do
    a = fixture({ npcID = npc, level = 80, classification = "normal" })
    local c = a:GetAutoShowState().resolvedContext
    expect(a:GetMainWindow():IsShown() and c and c.npcID == npc and
        c.journalInstanceID == 1307 and c.difficultyID == 14 and c.targetIdentity,
        "current supported raid unit resolves " .. npc)
end
for _, npc in ipairs({ 217489, 217491 }) do
    a = fixture({ instanceID = 2657, npcID = npc, level = 30, classification = "elite" })
    expect(a:GetAutoShowState().resolvedContext.encounterID == 2608 and
        a:GetMainWindow():IsShown(), "older multi-boss unit resolves without skull " .. npc)
end
for _, case in ipairs({
    { { instanceID = 999 }, "unsupported-raid" },
    { { npcID = 999 }, "unsupported-target" },
    { { noGUID = true }, "target-identity-unavailable" },
    { { guid = "Player-1-1" }, "unsupported-target-type" },
    { { guid = "Creature-malformed" }, "unsupported-target-type" },
    { { secretGUID = true, guid = "secret" }, "restricted-target-identity" },
    { { journalID = 999 }, "journal-instance-mismatch" },
    { { noJournal = true }, "journal-instance-unavailable" },
    { { noEncounter = true }, "encounter-data-mismatch" },
    { { returnedEncounterID = 999 }, "encounter-data-mismatch" },
    { { encounterJournalID = 999 }, "encounter-data-mismatch" },
    { { encounterMapID = 999 }, "encounter-data-mismatch" },
    { { difficultyID = 0 }, "difficulty-unavailable" },
}) do
    a = fixture(case[1])
    expect(not a:GetMainWindow():IsShown() and a:GetAutoShowState().failureReason == case[2],
        "fail closed: " .. case[2])
end
a, state, event = fixture()
window, runtime = a:GetMainWindow(), a:GetWindowState()
key = runtime.contextKey
window.encounterData = { old = true }
state.difficultyID = 16
event("PLAYER_DIFFICULTY_CHANGED")
expect(window:IsShown() and runtime.contextKey ~= key and runtime.difficultyID == 16 and
    window.encounterData == nil and runtime.resolvedContext.difficultyID == 16,
    "raid difficulty invalidates displayed context")
window.encounterData = { old = true }
state.npcID = 240434
event("UNIT_FLAGS", "target")
expect(runtime.resolvedContext.encounterID == 2734 and window.encounterData == nil,
    "encounter identity updates even without target event")
state.npcID = 999
event("UNIT_FLAGS", "target")
expect(not window:IsShown() and runtime.resolvedContext == nil, "unknown target removes resolved context")
for _, case in ipairs({
    { { instanceType = "party", difficultyID = 23, instanceID = 999 }, "unsupported-dungeon" },
    { { instanceType = "party", difficultyID = 23,
        challengeGameMaps = { [501] = 2912, [502] = 2912 } }, "ambiguous-dungeon" },
}) do
    a = fixture(case[1])
    expect(not a:GetMainWindow():IsShown() and a:GetAutoShowState().failureReason == case[2],
        "dungeon fails closed: " .. case[2])
    SlashCmdList.SPEKIFIER("toggle")
    expect(a:GetMainWindow():IsShown() and not a:GetWindowState().resolvedContext and
        a:GetMainWindow().status.text:find("reward source", 1, true), "unsupported manual preview explains failure")
end
a, state, event = fixture({ instanceType = "party", difficultyID = 23, challengeMaps = {} })
expect(not a:GetMainWindow():IsShown() and not a:GetAutoShowState().dungeonVisit.prompted,
    "unavailable challenge catalog does not consume visit")
state.challengeMaps = { 501 }
event("CHALLENGE_MODE_MAPS_UPDATE")
local c = a:GetWindowState().resolvedContext
expect(a:GetMainWindow():IsShown() and c.challengeModeID == 501 and c.visitID and
    c.rewardSource.kind == "challenge-mode-end-of-run" and c.difficultyID == 23 and
    c.lootMode == "mythic-plus" and not c.encounterID and not c.targetIdentity,
    "delayed catalog resolves target-free dungeon-wide reward identity")
for _, api in ipairs({ "journal", "encounter", "challenge" }) do
    a, state, event = fixture(api == "challenge" and
        { instanceType = "party", difficultyID = 23 } or nil)
    if api == "journal" then C_EncounterJournal = nil
    elseif api == "encounter" then EJ_GetEncounterInfo = nil
    else C_ChallengeMode = nil end
    event("PLAYER_ENTERING_WORLD")
    expect(not a:GetMainWindow():IsShown() and not a:GetAutoShowState().resolvedContext,
        "missing API fails closed: " .. api)
end
a, state, event = fixture({ instanceType = "party", difficultyID = 23 })
window = a:GetMainWindow()
window.encounterData = { old = true }
state.challengeMaps = { 502 }
state.challengeGameMaps = { [502] = 2912 }
event("CHALLENGE_MODE_MAPS_UPDATE")
expect(window.encounterData == nil and a:GetWindowState().resolvedContext.challengeModeID == 502,
    "changed reward source invalidates data within same visit")
expect(a.autoShowFrame.events.CHALLENGE_MODE_MAPS_UPDATE, "catalog completion event registered")
-- Production debug mode reports failures, toggles immediately, and stays quiet
-- when disabled. Timer mocks reproduce entry data arriving without another event.
local function logged(state, text)
    for _, message in ipairs(state.messages) do
        if message:find(text, 1, true) then return true end
    end
    return false
end
a, state, event = fixture({ inInstance = false })
expect(#state.messages == 0, "debug disabled is silent")
SlashCmdList.SPEKIFIER("debugmode")
expect(a:IsDebugEnabled() and logged(state, "DEBUG_MODE_ENABLED") and
    logged(state, "decision=ineligible-instance"), "toggle immediately diagnoses current context")
state.messages = {}
state.inInstance, state.instanceType, state.difficultyID = true, "party", 8
state.challengeMaps = {}
event("PLAYER_ENTERING_WORLD")
expect(logged(state, "PLAYER_ENTERING_WORLD") and logged(state, "challenge-data-unavailable"),
    "failed dungeon entry produces debug output")
expect(not a:GetMainWindow():IsShown() and not a:GetAutoShowState().dungeonVisit.prompted,
    "missing data retains unconsumed prompt")
expect(state.mapRequests > 0, "Mythic+ data requested without opening Blizzard UI")
state.challengeMaps = { 501 }
state:Tick()
expect(a:GetMainWindow():IsShown() and logged(state, "window-shown"),
    "retry opens when data arrives without a catalog event")
a:GetMainWindow():Hide()
state:Tick()
expect(not a:GetMainWindow():IsShown(), "retry cannot reopen dismissed visit")
state.messages = {}
event("CHALLENGE_MODE_START")
expect(logged(state, "decision=dismissed"), "debug explains dismissed visit")
local count = #state.messages
event("UNIT_HEALTH", "target")
event("UNIT_HEALTH", "target")
expect(#state.messages == count, "unchanged unit events do not spam debug")
SlashCmdList.SPEKIFIER("debugmode")
state.messages = {}
event("PLAYER_ENTERING_WORLD")
expect(#state.messages == 0, "disabling debug silences entry output")

for _, lag in ipairs({ "instance", "journal", "map-info" }) do
    a, state, event = fixture({ instanceType = "party", difficultyID = 8,
        instanceID = lag == "instance" and 0 or 2912,
        noJournal = lag == "journal", missingMapInfo = lag == "map-info" })
    expect(not a:GetMainWindow():IsShown(), "entry waits for " .. lag)
    state.instanceID, state.noJournal, state.missingMapInfo = 2912, false, false
    state:Tick()
    expect(a:GetMainWindow():IsShown(), "retry resolves delayed " .. lag)
end

a, state, event = fixture({ instanceType = "party", difficultyID = 8, challengeMaps = {} })
for i = 1, 5 do state:Tick() end
expect(#state.timers == 0, "entry retries stop after five attempts")
expect(not a:GetMainWindow():IsShown(), "exhausted retries do not invent a reward context")
state.challengeMaps = { 501 }
event("CHALLENGE_MODE_MAPS_UPDATE")
expect(a:GetMainWindow():IsShown(), "catalog event still resolves after retry budget")

a, state, event = fixture({ instanceType = "party", difficultyID = 8, challengeMaps = {} })
state.inInstance = false
event("ZONE_CHANGED_NEW_AREA")
state.challengeMaps = { 501 }
state:Tick()
expect(not a:GetMainWindow():IsShown(), "stale entry callback cannot open outside dungeon")

a, state, event = fixture({ instanceType = "party", difficultyID = 8, challengeMaps = {} })
state.challengeMaps, state.combat = { 501 }, true
state:Tick()
expect(not a:GetMainWindow():IsShown(), "retry respects combat")
state.combat = false
event("PLAYER_REGEN_ENABLED")
expect(a:GetMainWindow():IsShown(), "combat-deferred retry prompts after combat")

a, state, event = fixture({ instanceType = "party", difficultyID = 8, instanceID = 999 },
    { settings = { debugEnabled = true } })
expect(logged(state, "decision=unsupported-dungeon"), "unsupported dungeon reports rejection")
a:DebugPrint("Mixed values", false, nil, 8)
expect(logged(state, "Mixed values false nil 8"), "debug accepts boolean nil and numeric values")
a, state, event = fixture({ instanceType = "party", difficultyID = 8,
    name = "Localized Dungeon", difficultyName = "Mythic Keystone" },
    { settings = { debugEnabled = true } })
expect(logged(state, "instance=Localized Dungeon difficulty=Mythic Keystone"),
    "debug mode displays client instance and difficulty names")
expect(not logged(state, "instance=2912") and not logged(state, "difficulty=8"),
    "debug mode replaces numeric instance and difficulty labels")
state.messages = {}
SlashCmdList.SPEKIFIER("debug")
expect(logged(state, "Game Instance: Localized Dungeon") and
    logged(state, "Dungeon Instance: Localized Dungeon") and
    logged(state, "Instance Difficulty: Mythic Keystone"), "manual debug also displays names")
state.name, state.difficultyName = "New Dungeon", "Mythic"
event("PLAYER_ENTERING_WORLD")
expect(logged(state, "instance=New Dungeon difficulty=Mythic"), "name refresh uses current client data")
state.name, state.difficultyName = nil, nil
event("PLAYER_ENTERING_WORLD")
expect(logged(state, "instance=Unknown instance difficulty=Unknown difficulty"),
    "unavailable names have readable fallbacks")
state.name, state.difficultyName, state.difficultyID = "", "", 0
event("PLAYER_ENTERING_WORLD")
expect(logged(state, "instance=Unknown instance difficulty=None"),
    "empty names and no difficulty have readable fallbacks")
originalPrint("Passed " .. checks .. " lifecycle, resolver and debug checks")

-- Reuse the lifecycle fixture for focused provider/window integration checks.
return fixture
