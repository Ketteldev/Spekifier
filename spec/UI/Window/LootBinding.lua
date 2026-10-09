-- Reuses lifecycle fixtures and tests production context-to-result delivery.
local originalPrint = print
local fixture = assert(loadfile("spec/Modules/Context/AutoShow.lua"))()
local checks = 0
local function expect(value,label) assert(value,label); checks=checks+1 end
local function setup(overrides)
    local addon,state,event=fixture(overrides)
    local journal={difficulty=16,slot=10,classID=2,specID=65,stale=false,queries=0}
    function UnitClass() return "Warrior","WARRIOR",1 end
    function EJ_SelectInstance(id) journal.instance,journal.encounter=id,nil end
    function EJ_SelectEncounter(id) journal.encounter=id end
    function EJ_GetDifficulty() return journal.difficulty end
    function EJ_SetDifficulty(id) journal.difficulty=id end
    function EJ_IsValidInstanceDifficulty() return true end
    function EJ_GetLootFilter() return journal.classID,journal.specID end
    function EJ_SetLootFilter(c,s) journal.classID,journal.specID=c,s end
    function EJ_IsLootListOutOfDate() return journal.stale end
    function EJ_GetNumLoot() journal.queries=journal.queries+1; return 1 end
    C_EncounterJournal.GetSlotFilter=function() return journal.slot end
    C_EncounterJournal.ResetSlotFilter=function() journal.slot=15 end
    C_EncounterJournal.SetSlotFilter=function(slot) journal.slot=slot end
    C_EncounterJournal.GetLootInfoByIndex=function()
        return {itemID=journal.specID,name="Spec loot",icon=123,link=not journal.missingLink and "item:"..journal.specID or nil}
    end
    EncounterJournal=nil; hooksecurefunc=nil; C_Item=nil; C_SeasonInfo=nil
    do
        local addonName, addonNamespace = "Spekifier",{Spekifier=addon}
        for _, file in ipairs({
            "src/Modules/Loot/Model.lua",
            "src/Modules/Loot/Provider.lua",
            "src/Modules/Loot/Journal.lua",
            "src/Modules/Loot/Events.lua",
        }) do
            assert(loadfile(file))(addonName, addonNamespace)
        end
    end
    addon:RefreshAutoShow("LOOT_PROVIDER_READY")
    return addon,state,event,journal
end
local a,state,event,j=setup()
local w=a:GetMainWindow()
expect(w.encounterData.state=="ready" and w.encounterData.specs[1].items[1].itemID==1,
    "resolved window receives every player spec")
expect(a:GetSpecColumn(1).rows[1].item.itemID == 1 and a:GetSpecColumn(1).rows[1]:IsShown(),
    "provider ready result renders actual item row")
local function debugContains(text)
    state.messages = {}
    SlashCmdList.SPEKIFIER("debug")
    for _, message in ipairs(state.messages) do
        if message:find(text,1,true) then return true end
    end
    return false
end
expect(debugContains("Spec 1 (1): 1 item [ready]"),"debug labels completed spec count by name and ID")
local savedData=w.encounterData
w.encounterData={specs={
    [1]={state="empty",items={}},
    [2]={state="loading",items={{itemID=1}}},
    [3]={state="failed",reason="loot-data-timeout",items={}},
}}
expect(debugContains("Spec 1 (1): 0 items [empty]"),"debug distinguishes confirmed empty loot")
expect(debugContains("Spec 2 (2): 1 item received; count incomplete [loading]"),"debug marks partial loading counts")
expect(debugContains("Spec 3 (3): count unavailable [failed: loot-data-timeout]"),"debug avoids false zero on failure")
w.encounterData=nil
expect(debugContains("Spec 1 (1): 1 item [ready]"),"debug repairs a lost result reference")
w.encounterData={specs={
    [1]={state="unsupported",reason="journal-difficulty-unavailable",items={},
        explanation="Verified chest pool source required",
        difficultyDiagnostics={requestedID=8,baseID=8,availableIDs={1,2,23}}},
}}
local queriesBeforeDebug=j.queries
expect(debugContains("Loot Source: Verified chest pool source required"),"debug explains source limitation")
expect(debugContains("Requested Journal Difficulty ID: 8"),"debug identifies rejected difficulty")
expect(debugContains("Available Journal Difficulty IDs: 1, 2, 23"),"debug reports client-supported difficulty IDs")
expect(j.queries==queriesBeforeDebug,"diagnostics do not issue additional loot queries")
w.encounterData=savedData
local count=j.queries
for i=1,10 do event("UNIT_HEALTH","target") end
expect(j.queries==count,"unchanged target does not issue full loot queries")
state.npcID=240434; event("PLAYER_TARGET_CHANGED")
expect(w.encounterData.context.encounterID==2734,"boss switch immediately replaces displayed data")
expect(a:GetSpecColumn(1).rows[1].item == w.encounterData.specs[1].items[1],
    "boss switch replaces row binding with new provider data")
state.difficultyID=16; event("PLAYER_DIFFICULTY_CHANGED")
expect(w.encounterData.context.difficultyID==16,"difficulty switch replaces displayed result")
a:HideWindow("dismissed")
expect(w.encounterData==nil and a.LootProvider.active==nil,"close cancels data ownership")
expect(a:GetSpecColumn(1).rows[1].item == nil and not a:GetSpecColumn(1).rows[1]:IsShown(),
    "close removes rendered provider items")
a:ShowWindow("manual")
expect(w.encounterData.state=="ready","manual reopen can reuse completed data")
state.combat=true; event("PLAYER_REGEN_DISABLED")
expect(w.encounterData==nil and a.LootProvider.active==nil,"combat invalidates window data and callbacks")

a,state,event,j=setup(); w=a:GetMainWindow()
a.LootProvider:Invalidate(); j.missingLink=true
state.npcID=240434; event("PLAYER_TARGET_CHANGED")
expect(w.encounterData.state=="loading","new boss can remain loading")
expect(a:GetSpecColumn(1).rows[1].item == nil and a:GetSpecColumn(1).message.text:find("Loading"),
    "delayed provider data clears prior boss rows and explains loading")
state.npcID=240432; event("PLAYER_TARGET_CHANGED")
j.missingLink=false; state:Tick()
expect(w.encounterData.context.encounterID==2736 and w.encounterData.state=="ready",
    "old boss timer cannot render after rapid switch")

a,state,event,j=setup({instanceType="party",instanceID=100,difficultyID=23}); w=a:GetMainWindow()
expect(w.encounterData.context.kind=="dungeon" and w.encounterData.context.visitID==1 and
    w.encounterData.specs[1].journalDifficultyID==23,"dungeon window consumes Mythic+ provider result")
a.LootProvider:Invalidate(); j.missingLink=true
state.difficultyID=8; event("CHALLENGE_MODE_START")
expect(w.encounterData.state=="loading","keystone transition has its own difficulty request")
state.instanceType="none"; state.inInstance=false; event("PLAYER_ENTERING_WORLD")
j.missingLink=false; state:Tick()
expect(w.encounterData==nil and a.LootProvider.active==nil,"dungeon exit rejects pending results")
state.instanceType="party"; state.inInstance=true; event("PLAYER_ENTERING_WORLD")
expect(w.encounterData.context.visitID==2 and w.encounterData.state=="ready",
    "re-entry binds fresh data to new visit")
expect(debugContains("Loot Query Journal Difficulty ID: 23"),"debug shows actual combined-pool query difficulty")
expect(debugContains("Loot Query Scope: all dungeon bosses; Mythic+ preview"),"debug distinguishes query scope from reward mode")
count=j.queries; state.exists=false; event("PLAYER_TARGET_CHANGED")
expect(j.queries==count and w.encounterData.context.visitID==2,"dungeon target changes do not request loot")
-- Repeated diagnostics must continue loading independently of a dismissed
-- dungeon preview, without reopening it or consuming another visit prompt.
a,state,event,j=setup({instanceType="party",instanceID=100,difficultyID=23})
w=a:GetMainWindow()
a:HideWindow("dismissed")
count=j.queries
expect(debugContains("Spec 1 (1): 1 item [ready]") and not w:IsShown(),
    "dismissed preview still permits cached diagnostic counts")
expect(j.queries==count and a:GetAutoShowState().dungeonVisit.prompted,
    "hidden diagnostics preserve cache and visit prompting")
a.LootProvider:Invalidate()
state.difficultyID=8; event("CHALLENGE_MODE_START"); j.missingLink=true
expect(debugContains("Spec 1 (1): 1 item received; count incomplete [loading]"),
    "hidden diagnostics begin a pending current-context query")
count=j.queries
for i=1,3 do SlashCmdList.SPEKIFIER("debug") end
expect(j.queries==count and a:GetDebugLootData().state=="loading",
    "three debug polls retain pending results without repeating queries")
j.missingLink=false; state:Tick()
expect(debugContains("Spec 1 (1): 1 item [ready]") and not w:IsShown(),
    "hidden diagnostic data completes without reopening preview")
state.combat=true; event("PLAYER_REGEN_DISABLED")
expect(debugContains("Loot Counts Unavailable: combat"),"diagnostics reject counts during combat")
state.combat=false; event("PLAYER_REGEN_ENABLED")
state.instanceType="none"; state.inInstance=false; event("PLAYER_ENTERING_WORLD")
expect(debugContains("Loot Counts Unavailable: ineligible-instance"),
    "diagnostics never retain previous dungeon counts after exit")
-- Closing the preview while Journal data is delayed must not erase the
-- diagnostic comparison or leave an orphaned loading request.
a,state,event,j=setup({instanceType="party",instanceID=100,difficultyID=23})
w=a:GetMainWindow(); a.LootProvider:Invalidate(); j.missingLink=true
state.difficultyID=8; event("CHALLENGE_MODE_START")
expect(w.encounterData.state=="loading","visible preview starts delayed comparison")
a:HideWindow("dismissed")
expect(debugContains("Spec 1 (1): 1 item received; count incomplete [loading]"),
    "debug restarts canceled partial data with preview hidden")
j.missingLink=false; state:Tick()
expect(debugContains("Spec 1 (1): 1 item [ready]"),"canceled window data completes through diagnostics")
-- A visit change while a hidden comparison is pending rejects its callbacks.
a.LootProvider:Invalidate(); state.difficultyID=23; event("PLAYER_DIFFICULTY_CHANGED"); j.missingLink=true
SlashCmdList.SPEKIFIER("debug")
state.inInstance=false; state.instanceType="none"; event("PLAYER_ENTERING_WORLD")
j.missingLink=false; state:Tick()
expect(a:GetDebugLootData()==nil,"prior-visit diagnostic timers cannot supply counts after exit")
state.inInstance=true; state.instanceType="party"; event("PLAYER_ENTERING_WORLD")
expect(a:GetDebugLootData().context.visitID==2,"re-entry diagnostics use the fresh visit")
-- The refresh flag can remain set while every item is fully populated.
a,state,event,j=setup({instanceType="party",instanceID=100,difficultyID=23})
a.LootProvider:Invalidate(); j.stale=true
state.difficultyID=8; event("CHALLENGE_MODE_START")
expect(debugContains("Spec 1 (1): 1 item [ready]"),"complete Journal rows show ready despite refresh flag")
a.LootProvider:Invalidate(); j.missingLink=true
state.difficultyID=23; event("PLAYER_DIFFICULTY_CHANGED")
expect(debugContains("Missing data: rows=0, names=0, icons=0, links=1"),
    "debug identifies the actual missing data behind a pending count")
for i=1,8 do state:Tick() end
expect(debugContains("count incomplete [failed: loot-data-timeout]") and
    debugContains("Missing data: rows=0, names=0, icons=0, links=1"),
    "real missing-link timeout retains useful diagnostics")
originalPrint("Passed "..checks.." provider/window integration checks")


-- Reuse the real provider fixture for shared-pool integration checks.
return setup
