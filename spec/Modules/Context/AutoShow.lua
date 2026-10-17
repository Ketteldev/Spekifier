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

    function UIDropDownMenu_SetWidth(d, width) d.width = width end
    function UIDropDownMenu_SetText(d, text) d.text = text end
    function UIDropDownMenu_CreateInfo() return {} end
    function UIDropDownMenu_AddButton(info) state.menu[#state.menu + 1] = info end
    function UIDropDownMenu_Initialize(d, callback) d.initialize = callback end
    state.menu = {}
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
        assert(not state.forbidTargetReads, "target API read forbidden")
        state.targetReads = state.targetReads + 1
    end
    function UnitExists() readTarget(); return state.exists end
    function UnitCanAttack() readTarget(); return state.attackable end
    function UnitIsDeadOrGhost() readTarget(); return state.dead end
    function UnitClass() return state.classToken or "Mage", state.classToken or "MAGE" end
    function GetNumClasses() return 13 end
    function GetClassInfo(index)
        local tokens = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
            "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"}
        return tokens[index], tokens[index], index
    end
    function UnitClassification() readTarget(); return state.classification end
    function UnitLevel() readTarget(); return state.level end
    function UnitGUID()
        readTarget()
        if state.noGUID then return nil end
        return state.guid or ("Creature-0-1-2912-1-" .. state.npcID .. "-00000001")
    end
    function issecretvalue(value) return state.secretGUID and value == state.guid end
    C_EncounterJournal = { GetInstanceForGameMap = function(mapID)
        state.journalLookups = (state.journalLookups or 0) + 1
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
    -- Match the game API signature so editor inference accepts unit arguments.
    local defaultIDs = state.instanceID == 3004 and {2888,2874,2882,2894,2871,2887,2883,2895} or
        (state.instanceID == 2987 and {2849} or (state.instanceID == 2657 and {2608} or
        {2733,2734,2735,2736,2737,2738}))
    if not state.journalEncounters then
        state.journalEncounters = {}
        for _, id in ipairs(defaultIDs) do
            state.journalEncounters[#state.journalEncounters + 1] = {id=id,name="Localized Boss " .. id}
        end
    end
    function EJ_GetEncounterInfoByIndex(index, journalID)
        assert(journalID == (state.journalID or (state.instanceID == 2657 and 1273 or 1307)), "explicit Journal instance required")
        if state.noEncounter then return nil end
        local entry = state.journalEncounters and state.journalEncounters[index]
        if entry then return entry.name, nil, entry.id end
    end
    function EJ_GetCreatureInfo(index, encounterID)
        for _, entry in ipairs(state.journalEncounters or {}) do
            if entry.id == encounterID then
                local name = entry.creatures and entry.creatures[index]
                if name then return 999000 + index, name end
            end
        end
    end
    function UnitName(unit)
        if unit == "target" then readTarget(); return state.targetName or "Unknown target" end
        return "Tester"
    end
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
    local function event(name, ...) addon.autoShowFrame:Fire("OnEvent", name, ...) end
    return addon, state, event, frames
end

-- Raid prompting and comparison never inspect a target, including secret identities.
for _, overrides in ipairs({{}, {exists=false}, {dead=true}, {attackable=false},
    {npcID=999}, {noGUID=true}, {secretGUID=true,guid="secret"}, {forbidTargetReads=true}}) do
    local a,s,event=fixture(overrides)
    local w,c=a:GetMainWindow(),a:GetAutoShowState().resolvedContext
    expect(w:IsShown() and c.encounterID==2733, "raid entry selects first Journal encounter")
    expect(c.identitySource=="encounter-picker" and not c.targetIdentity and not c.npcID,
        "raid context has no restricted identity")
    expect(s.targetReads==0 and not a:GetAutoShowState().targetingBoss,"target reads absent")
    expect(w.encounterPicker:IsShown() and w.sharedLoot.frame:IsShown(),"picker visible without loot")
    local key=a:GetWindowState().contextKey
    event("PLAYER_TARGET_CHANGED")
    expect(a:GetWindowState().contextKey==key and s.targetReads==0,"target events preserve picker context")
    a:HideWindow("dismissed"); event("PLAYER_TARGET_CHANGED"); s:Tick()
    expect(not w:IsShown(),"target changes and retries do not undo dismissal")
end
local a,state,event,frames=fixture()
local window,runtime=a:GetMainWindow(),a:GetWindowState()
expect(not a.autoShowFrame.events.PLAYER_TARGET_CHANGED and not a.autoShowFrame.events.UNIT_HEALTH,
    "instance workflow needs no target event subscriptions")
local key=runtime.contextKey
window.encounterData={old=true}
expect(a:SelectRaidEncounter(2734),"select listed encounter")
expect(runtime.contextKey~=key and runtime.resolvedContext.encounterID==2734 and window.encounterData==nil,
    "selection replaces loot ownership synchronously")
expect(window.encounterPicker.dropdown.text=="Localized Boss 2734","dropdown displays selected encounter")
expect(window.header.text:find("Test Dungeon",1,true),"header shows raid name")
expect(not a:SelectRaidEncounter(999),"unknown encounter rejected")
local selectedKey=runtime.contextKey
state.difficultyID=17; event("PLAYER_DIFFICULTY_CHANGED")
expect(runtime.resolvedContext.encounterID==2734 and runtime.difficultyID==17 and
    runtime.contextKey~=selectedKey,"difficulty changes retain encounter and invalidate loot")
state.menu={}; window.encounterPicker.dropdown.initialize(nil,1)
expect(#state.menu==6 and state.menu[2].checked,"dropdown contains Journal list and checked selection")
local stale=state.menu[3].func
state.difficultyID=15; event("PLAYER_DIFFICULTY_CHANGED"); stale()
expect(runtime.resolvedContext.encounterID==2734,"stale menu callbacks cannot change new context")
state.menu={}; window.encounterPicker.dropdown.initialize(nil,1); state.menu[4].func()
expect(runtime.resolvedContext.encounterID==2736,"native dropdown callback selects encounter")
state.combat=true; event("PLAYER_REGEN_DISABLED")
expect(not window:IsShown() and not a:SelectRaidEncounter(2733),"combat closes and blocks picker")
state.combat=false; event("PLAYER_REGEN_ENABLED")
expect(not window:IsShown() and a:GetAutoShowState().resolvedContext.encounterID==2736,
    "ordinary combat end cannot reopen a shown raid comparison")
event("ENCOUNTER_START", 90001, "Runtime boss", 15)
event("ENCOUNTER_END", 90001, "Runtime boss", 15, 20, 1)
expect(not window:IsShown() and a:GetAutoShowState().resolvedContext.encounterID==2736,
    "boss encounter end cannot reopen the raid entry comparison")
a:HideWindow("dismissed")
event("PLAYER_TARGET_CHANGED"); expect(not window:IsShown(),"retarget never reopens dismissed raid")
state.inInstance=false; event("ZONE_CHANGED_NEW_AREA")
state.inInstance=true; event("ZONE_CHANGED_NEW_AREA")
expect(window:IsShown() and runtime.resolvedContext.encounterID==2733,"new visit resets encounter")
state.journalEncounters={{id=8000,name="Replacement"}}; event("PLAYER_ENTERING_WORLD")
expect(runtime.resolvedContext.encounterID==8000,"removed selection falls back to first current encounter")
state.instanceType="party"; state.difficultyID=23; event("ZONE_CHANGED_NEW_AREA")
expect(runtime.contextKind=="dungeon" and not window.encounterPicker:IsShown(),"dungeon hides picker")
expect(not a:SelectRaidEncounter(8000),"dungeon cannot accept raid selection")
state.inInstance=false; event("ZONE_CHANGED_NEW_AREA")
expect(not window:IsShown(),"exit closes preview")

-- Menu callbacks must recheck the live instance even before its zone event arrives.
a,state,event=fixture()
local picker=a:GetMainWindow().encounterPicker
state.menu={}; picker.dropdown.initialize(nil,1)
local pendingMenu=state.menu[2].func
state.instanceID=3004; pendingMenu()
expect(a:GetAutoShowState().instanceID==3004 and a:GetAutoShowState().resolvedContext.encounterID==2733,
    "stale click refreshes instance and cannot select prior raid encounter")
a,state,event=fixture()
state.menu={}; a:GetMainWindow().encounterPicker.dropdown.initialize(nil,1)
pendingMenu=state.menu[2].func
state.combat=true; pendingMenu()
expect(a:GetAutoShowState().resolvedContext.encounterID==2733,"menu callback cannot change encounter during combat")
-- Malformed/incomplete catalogs must not yield partial selectable lists.
a,state,event=fixture()
state.journalEncounters={}
for i=1,100 do state.journalEncounters[i]={id=i,name="Boss "..i} end
event("PLAYER_ENTERING_WORLD")
expect(not a:GetMainWindow():IsShown() and a:GetAutoShowState().failureReason=="journal-discovery-incomplete",
    "bounded enumeration rejects unterminated catalogs")

-- Miniboss/trash combat is not a raid encounter, regardless of target level/classification.
for _, difficulty in ipairs({17,14,15,16}) do
    for _, close in ipairs({"shown","dismissed","selected","manual"}) do
        local a,s,ev=fixture({difficultyID=difficulty,level=92,npcID=999,forbidTargetReads=true,
            selectionModule=close=="selected"})
        local w=a:GetMainWindow()
        a:SelectRaidEncounter(2734)
        if close=="dismissed" then a:HideWindow("dismissed")
        elseif close=="selected" then a:GetSpecColumn(2).frame:Fire("OnClick","LeftButton")
        elseif close=="manual" then a:HideWindow("dismissed"); a:ShowWindow("manual") end
        for fight=1,3 do
            s.combat=true; ev("PLAYER_REGEN_DISABLED")
            s.combat=false; ev("PLAYER_REGEN_ENABLED")
            ev("ZONE_CHANGED_NEW_AREA"); ev("PLAYER_DIFFICULTY_CHANGED"); s:Tick()
            a:InitializeAutoShow()
            expect(not w:IsShown(),"level-92/non-encounter combat cannot reopen: "..difficulty.."/"..close)
        end
        expect(a:GetAutoShowState().resolvedContext.encounterID==2734 and s.targetReads==0,
            "trash suppression retains chosen encounter without inspecting unit identity")
        for _, success in ipairs({0,1}) do
            s.combat=true; ev("PLAYER_REGEN_DISABLED")
            ev("ENCOUNTER_START",55555,"Real boss",difficulty)
            ev("ENCOUNTER_END",55555,"Real boss",difficulty,20,success)
            s.combat=false; ev("PLAYER_REGEN_ENABLED")
            ev("ENCOUNTER_END",55555,"Real boss",difficulty,20,success)
            expect(not w:IsShown() and a:GetAutoShowState().raidVisit.prompted,
                "boss kills/wipes never rearm the raid entry prompt")
        end
        a:ShowWindow("manual")
        expect(w:IsShown() and a:GetWindowState().resolvedContext.encounterID==2734,
            "manual reopening retains selected encounter after boss fights")
        a:HideWindow("dismissed")
        s.inInstance=false; ev("ZONE_CHANGED_NEW_AREA")
        s.inInstance=true; ev("ZONE_CHANGED_NEW_AREA")
        expect(w:IsShown() and w.showCount>=2,"leaving and reentering grants one new entry prompt")
        a:HideWindow("dismissed"); ev("PLAYER_ENTERING_WORLD"); s:Tick()
        expect(not w:IsShown(),"duplicate world events never recreate consumed visit")
    end
end
a,state,event=fixture()
expect(not a.autoShowFrame.events.ENCOUNTER_START and not a.autoShowFrame.events.ENCOUNTER_END,
    "entry-only prompting does not subscribe to boss encounter events")
for _, setting in ipairs({"enabled","autoShowNormalRaid"}) do
    a,state,event=fixture(nil,{settings={[setting]=false}})
    event("ENCOUNTER_START",12345,"Boss",14)
    event("ENCOUNTER_END",12345,"Boss",14,20,1)
    expect(not a:GetMainWindow():IsShown(),"boss events never create a suppressed entry prompt")
end
a,state,event=fixture({instanceType="party",difficultyID=23})
a:HideWindow("dismissed"); event("ENCOUNTER_START",12345,"Dungeon boss",23)
event("ENCOUNTER_END",12345,"Dungeon boss",23,5,1)
expect(not a:GetMainWindow():IsShown(),"dungeon boss events cannot rearm consumed dungeon entry")
a,state,event=fixture({combat=true})
state.inInstance=false; event("ZONE_CHANGED_NEW_AREA")
state.combat=false; event("PLAYER_REGEN_ENABLED")
expect(not a:GetMainWindow():IsShown(),"departed deferred raid entry is canceled")
a,state,event=fixture()
a:HideWindow("dismissed"); state.combat=true; event("PLAYER_REGEN_DISABLED")
state.difficultyID=17; event("PLAYER_DIFFICULTY_CHANGED")
state.combat=false; event("PLAYER_REGEN_ENABLED")
expect(not a:GetMainWindow():IsShown(),"difficulty change during trash cannot revive consumed raid prompt")
a:ShowWindow("manual")
expect(a:GetMainWindow():IsShown(),"manual reopening remains available after ordinary combat")

-- Runtime discovery supports uncatalogued instances and all listed encounters/difficulties.
for _, difficulty in ipairs({17,14,15,16,250,233}) do
    a,state,event=fixture({instanceID=9001,journalID=9002,difficultyID=difficulty,
        journalEncounters={{id=9004,name="New Boss"},{id=9005,name="Another Boss"}}})
    expect(a:GetMainWindow():IsShown(),"uncatalogued raid entry "..difficulty)
    expect(a:SelectRaidEncounter(9005) and a:GetWindowState().resolvedContext.difficultyID==difficulty,
        "uncatalogued encounter selection keeps actual difficulty")
end
for _, difficulty in ipairs({17,14,15,16}) do
    a,state,event=fixture({instanceID=3004,journalID=1320,difficultyID=difficulty,
        secretGUID=true,guid="secret"})
    for _, id in ipairs({2888,2874,2882,2894,2871,2887,2883,2895}) do
        expect(a:SelectRaidEncounter(id) and a:GetWindowState().resolvedContext.encounterID==id,
            "all eight Venomous Abyss encounters selectable "..difficulty.."/"..id)
    end
    expect(state.targetReads==0,"all encounters work without target identity")
end
for _, case in ipairs({
    {{noJournal=true},"journal-instance-unavailable"},
    {{journalEncounters={}},"journal-discovery-incomplete"},
    {{journalEncounters={{id=1,name=""}}},"journal-discovery-incomplete"},
    {{journalEncounters={{id=1,name="Boss"},{id=1,name="Duplicate"}}},"journal-discovery-incomplete"},
    {{difficultyID=0},"difficulty-unavailable"},
}) do
    a=fixture(case[1])
    expect(not a:GetMainWindow():IsShown() and a:GetAutoShowState().failureReason==case[2],
        "raid discovery fails honestly: "..case[2])
end
a,state,event=fixture({noJournal=true})
state.noJournal=false; state:Tick()
expect(a:GetMainWindow():IsShown(),"bounded entry retry recovers delayed raid data")
a,state,event=fixture({journalEncounters={}})
state.journalEncounters={{id=1,name="Late Boss"}}; state:Tick()
expect(a:GetMainWindow():IsShown(),"bounded retry recovers delayed encounter list")
for _, opts in ipairs({{combat=true},{inInstance=false},{instanceType="party",difficultyID=2}}) do
    a=fixture(opts); expect(not a:GetMainWindow():IsShown(),"ineligible entry remains closed")
end
a,state,event=fixture({combat=true})
state.combat=false; event("PLAYER_REGEN_ENABLED")
expect(a:GetMainWindow():IsShown(),"combat entry defers raid prompt")
a=fixture(nil,{settings={enabled=false,custom="preserved",windowShown=true}})
expect(not a:GetMainWindow():IsShown() and a.db.settings.custom=="preserved" and
    a.db.settings.windowShown==nil,"preferences migrate without restoring visibility")
a:ShowWindow("manual")
expect(a:GetMainWindow():IsShown(),"manual raid picker ignores disabled automation")
a,state,event=fixture({inInstance=false})
a:ShowWindow("manual")
expect(a:GetMainWindow():IsShown() and not a:GetWindowState().resolvedContext and
    a:GetMainWindow().status.text:find("choose an encounter",1,true),"manual unsupported preview explains workflow")

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
expect(not window:IsShown(), "ordinary raid combat does not reset dismissal after dungeon transition")

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
    elseif api == "encounter" then EJ_GetEncounterInfoByIndex = nil
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
