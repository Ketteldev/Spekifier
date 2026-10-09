-- Run from repository root with Lua 5.1: lua spec/Modules/Loot/Provider.lua
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local function clone(t) local r = {}; for k,v in pairs(t) do r[k]=v end; return r end
local function raid(encounter, difficulty)
    return {kind="raid", instanceID=2912, journalInstanceID=1307,
        encounterID=encounter or 2733, difficultyID=difficulty or 14,
        lootMode="raid", contextKey="raid:" .. (encounter or 2733)}
end
local function dungeon(visit, difficulty)
    return {kind="dungeon", instanceID=2526, journalInstanceID=1201,
        challengeModeID=501, visitID=visit or 1, difficultyID=difficulty or 23,
        lootMode="mythic-plus", contextKey="dungeon:" .. (visit or 1),
        rewardSource={kind="challenge-mode-end-of-run",challengeModeID=501}}
end
local function fixture()
    local s = { instance=999, encounter=888, difficulty=16, classID=2, specID=65,
        slot=10, search="sword", combat=false, queries=0, mutations=0, timers={},
        hooks={}, shown=false, stale=false, requests=0, season=1, deliveries={}, expectedClass=1 }
    function s:Tick()
        local timers=self.timers; self.timers={}
        for _, fn in ipairs(timers) do fn() end
    end
    C_Timer={After=function(_, fn) s.timers[#s.timers+1]=fn end}
    function CreateFrame()
        return {RegisterEvent=function() end, SetScript=function(f,_,fn) f.onEvent=fn end}
    end
    EncounterJournal={instanceID=999,encounterID=888,IsShown=function() return s.shown end,
        HookScript=function(_,_,fn) s.onGuideHide=fn end}
    function InCombatLockdown() return s.combat end
    function hooksecurefunc(name, callback) s.hooks[name]=callback end
    local function mutate() s.mutations=s.mutations+1; assert(not s.shown, "mutated visible Guide") end
    function EJ_SelectInstance(id)
        mutate(); s.instance,s.encounter=id,nil
        if s.hooks.EJ_SelectInstance then s.hooks.EJ_SelectInstance(id) end
    end
    function EJ_SelectEncounter(id)
        mutate(); s.encounter=id
        if s.hooks.EJ_SelectEncounter then s.hooks.EJ_SelectEncounter(id) end
    end
    function EJ_GetDifficulty() return s.difficulty end
    function EJ_SetDifficulty(id) mutate(); s.difficulty=(s.clamp and id==23) and 2 or id end
    function EJ_IsValidInstanceDifficulty(id)
        if s.validDifficulties then return s.validDifficulties[id] == true end
        return not s.unsupported or id~=23
    end
    function EJ_GetLootFilter() return s.classID,s.specID end
    function EJ_SetLootFilter(class,spec) mutate(); s.classID,s.specID=class,spec end
    function EJ_IsLootListOutOfDate() return s.stale end
    function EJ_GetNumLoot()
        s.queries=s.queries+1
        assert(s.slot==15 and s.classID==s.expectedClass, "filters not normalized")
        if s.onQuery then s.onQuery() end
        if s.throw then error("injected query failure") end
        if s.specID==101 or s.zero then return 0 end
        return (s.instance==1201 or s.instance==1304) and 3 or 1
    end
    C_EncounterJournal={
        GetSlotFilter=function() return s.slot end,
        ResetSlotFilter=function() mutate(); s.slot=15 end,
        SetSlotFilter=function(slot) mutate(); s.slot=slot end,
        GetLootInfoByIndex=function(index)
            if s.missingRow then return nil end
            local itemID=s.specID*10 + (index==3 and 1 or index)
            return {itemID=itemID,encounterID=(s.instance==1201 or s.instance==1304) and (index==2 and 222 or 111) or s.encounter,
                displayAsPerPlayerLoot=s.bonusRow==index,
                name=not s.missingMetadata and "Loot "..itemID or nil,
                icon=not s.missingMetadata and itemID or nil,
                link=not s.missingLink and "item:"..itemID..":bonus" or nil,
                slot="Trinket",armorType="Misc",itemQuality="ffa335ee",displaySeasonID=s.itemSeason}
        end,
    }
    C_Item={GetItemInfo=function(id)
        if s.itemReady then return "Loaded item",nil,4,650,nil,nil,nil,nil,"INVTYPE_TRINKET",123 end
    end, RequestLoadItemDataByID=function() s.requests=s.requests+1 end}
    C_SeasonInfo={GetCurrentDisplaySeasonID=function() return s.season end}
    local addon={}
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
    local p=addon.LootProvider
    function s:Request(c, specs, current)
        return p:Request(c or raid(),1,specs or {100,101},function(result)
            self.deliveries[#self.deliveries+1]=result; self.result=result
        end,current)
    end
    function s:Restored()
        expect(self.instance==999 and self.encounter==888 and self.difficulty==16 and
            self.classID==2 and self.specID==65 and self.slot==10 and self.search=="sword",
            "shared Journal selections, filters and search preserved")
    end
    return p,s,addon
end
local p,s=fixture()
s:Request()
expect(s.deliveries[1].state=="loading" and s.result.state=="ready","loading then ready")
expect(s.result.specs[100].items[1].itemID==1001 and s.result.specs[101].state=="empty","per-spec eligibility and empty spec")
expect(s.result.context.encounterID==2733 and s.result.classID==1,"result identity")
expect(s.result.specs[100].items[1].name and s.result.specs[100].items[1].icon and
    s.result.specs[100].items[1].link=="item:1001:bonus","metadata and exact link retained")
s:Restored()
local count=s.queries
s.result.specs[100].items[1].name="modified by caller"
s:Request()
expect(s.queries==count and s.result.specs[100].items[1].name~="modified by caller","cache reused and isolated from caller")
s:Request(raid(2734))
expect(s.queries==count+2,"encounter cache isolation")
count=s.queries; s:Request(raid(2734,16))
expect(s.queries==count+2,"difficulty cache isolation")
count=s.queries; s.season=2; s:Request(raid(2734,16))
expect(s.queries==count+2,"season cache isolation")
p:Invalidate(); count=s.queries; s:Request(raid(2734,16))
expect(s.queries==count+2,"explicit invalidation")

p,s=fixture(); s:Request(dungeon(),{100})
expect(s.result.state=="ready" and #s.result.specs[100].items==2,"full dungeon table deduplicated")
expect(s.result.context.difficultyID==23 and s.result.specs[100].journalDifficultyID==23,
    "entry queries combined Mythic boss loot for Mythic+ preview")
expect(s.result.specs[100].rewardItemLevelKnown==false and
    s.result.specs[100].items[1].itemLevel==nil,"unknown key does not claim exact reward level")
s:Restored()
count=s.queries; s:Request(dungeon(2),{100})
expect(s.queries==count and s.result.context.visitID==2,"cached pool delivered with current visit")
count=s.queries; s:Request(dungeon(2,8),{100})
expect(s.queries==count+1,"actual difficulty included in dungeon cache")
local c=dungeon(3); c.challengeModeID=502; c.rewardSource.challengeModeID=502
count=s.queries; s:Request(c,{100})
expect(s.queries==count+1,"reward source included in cache")

p,s=fixture(); s.unsupported=true; s:Request(dungeon(),{100})
expect(s.result.state=="unsupported" and s.queries==0,"unsupported Mythic boss pool fails closed")
expect(s.result.specs[100].difficultyDiagnostics.requestedID==23 and
    s.result.specs[100].difficultyDiagnostics.baseID==23,
    "unsupported difficulty records requested and base identities")
s:Restored()
p,s=fixture(); s.clamp=true; s:Request(dungeon(),{100})
expect(s.result.reason=="journal-difficulty-mismatch" and s.queries==0,"difficulty coercion fails closed")
s:Restored()
p,s=fixture(); EJ_GetNumLoot=nil; s:Request()
expect(s.result.state=="unsupported" and s.mutations==0,"missing APIs fail closed")
p,s=fixture(); s:Request({kind="dungeon"})
expect(s.result.state=="unsupported" and s.mutations==0,"malformed context does not mutate Journal")
p,s=fixture(); c=dungeon(); c.rewardSource.kind="great-vault"; s:Request(c)
expect(s.result.state=="unsupported" and s.mutations==0,"Great Vault source rejected")

p,s=fixture(); s.zero=true; s.stale=true; s:Request()
expect(s.result.state=="loading","outdated zero count is loading")
s.stale=false; s:Tick()
expect(s.result.state=="empty","fresh zero count is empty")
s:Restored()
p,s=fixture(); s.throw=true; s:Request()
expect(s.result.state=="failed" and s.result.reason=="journal-query-failed","API exceptions are failures")
s:Restored()
p,s=fixture(); s.missingRow=true; s:Request()
expect(s.result.state=="loading","missing rows remain loading")
for i=1,8 do s:Tick() end
expect(s.result.state=="failed" and s.queries==7 and #s.timers==0,"retries bounded across specs")
s:Restored()

p,s=fixture(); s.missingMetadata=true; s:Request(raid(),{100})
expect(s.result.state=="loading" and s.requests==1,"item data explicitly requested")
count=s.queries; s.itemReady=true
p:OnEvent("ITEM_DATA_LOAD_RESULT",1001,true)
expect(s.result.state=="ready" and s.result.specs[100].items[1].name=="Loaded item" and
    s.result.specs[100].items[1].icon==123 and s.queries==count,"item event populates metadata without full query")
s:Tick(); expect(s.queries==count,"obsolete metadata timer performs no query")
p,s=fixture(); s.missingMetadata=true; s:Request(dungeon(),{100})
for i=1,6 do s:Tick() end
expect(s.result.state=="failed","unavailable item metadata times out distinctly")
s.itemReady=true; p:OnEvent("GET_ITEM_INFO_RECEIVED",1001,true)
expect(s.result.state=="ready" and s.result.specs[100].items[1].itemLevel==nil,
    "late metadata recovers without reload or invented reward level")
p,s=fixture(); s.missingLink=true; s:Request(raid(),{100})
expect(s.result.state=="loading","missing Journal link stays loading")
s.missingLink=false; p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001); s:Tick()
expect(s.result.state=="ready" and s.result.specs[100].items[1].link,"Journal event resolves missing link")

p,s=fixture(); s.missingLink=true; s:Request(raid(2733),{100})
local obsolete=#s.deliveries
s:Request(raid(2734,16),{100}); s.missingLink=false; s:Tick()
expect(#s.deliveries==obsolete+3 and s.result.context.encounterID==2734 and
    s.result.context.difficultyID==16,"rapid boss/difficulty changes discard obsolete timers")
p,s=fixture(); s.missingLink=true; local visit=1
s:Request(dungeon(1),{100},function(c) return c.visitID==visit end)
count=#s.deliveries; visit=2; s.missingLink=false; s:Tick()
expect(#s.deliveries==count,"prior-visit callback discarded by delivery guard")
s:Request(dungeon(2),{100},function(c) return c.visitID==visit end)
expect(s.result.context.visitID==2 and s.result.state=="ready","new visit receives its own result")
p,s=fixture(); s.missingLink=true; local token=s:Request(raid(),{100}); p:Cancel(token)
count=#s.deliveries; s:Tick(); p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001)
expect(#s.deliveries==count,"cancelled context cannot deliver")
p,s=fixture(); s.missingLink=true; s:Request(raid(),{100})
for i=1,100 do p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001) end
expect(#s.timers==1,"event bursts coalesced")

p,s=fixture(); s.shown=true; s:Request()
expect(s.result.state=="loading" and s.mutations==0,"open Adventure Guide is untouched")
s.shown=false; s:Tick()
expect(s.result.state=="ready","query resumes after Guide closes")
s:Restored()
p,s=fixture(); s.combat=true; s:Request()
expect(s.result.state=="loading" and s.mutations==0,"combat does not mutate shared Journal")
s.combat=false; s:Tick(); expect(s.result.state=="ready","query resumes outside combat")
p,s=fixture(); s.onQuery=function() p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001) end
s:Request()
expect(s.result.state=="ready" and s.queries==2 and #s.timers==0,"self-generated events do not overlap queries")
p,s=fixture(); s:Request(); count=s.queries
p:OnEvent("CHALLENGE_MODE_MAPS_UPDATE"); s:Tick()
expect(s.queries==count+2,"catalog updates invalidate completed data")
-- Class and specialization are also distinct cache dimensions.
count=s.queries
p:Request(raid(),1,{102},function(r) s.result=r end)
expect(s.queries==count+1 and s.result.specs[102].items[1].itemID==1021,"specialization cache isolation")
count=s.queries; s.expectedClass=2
p:Request(raid(),2,{102},function(r) s.result=r end)
expect(s.queries==count+1 and s.result.classID==2,"class cache isolation")
p,s=fixture(); s.itemSeason=2; s:Request(raid(),{100})
expect(s.result.state=="empty","out-of-season items match Adventure Guide exclusion")
p,s=fixture(); s.itemSeason=1; s:Request(raid(),{100})
expect(s.result.state=="ready","current-season loot retained")
p,s=fixture(); s.missingLink=true; s:Request(raid(),{100})
for i=1,6 do s:Tick() end
expect(s.result.state=="failed","missing link reaches bounded failure")
s.missingLink=false; p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001); s:Tick()
expect(s.result.state=="ready","late Journal event recovers a missing link")
p,s=fixture(); s.shown=true; s:Request(raid(),{100})
for i=1,6 do s:Tick() end
expect(s.result.state=="failed" and s.mutations==0,"visible Guide wait remains bounded")
s.shown=false; s.onGuideHide(); s:Tick()
expect(s.result.state=="ready","closing Guide resumes even after wait timeout")
p,s=fixture(); s:Request(raid(),{100})
-- A later selection to the instance-wide view must restore no encounter,
-- regardless of stale Blizzard UI encounter fields.
EJ_SelectInstance(999); s:Request(raid(2734),{100})
expect(s.instance==999 and s.encounter==nil,"instance-wide selection restored without stale UI encounter")
p,s=fixture(); s.missingLink=true; s:Request(raid(),{100})
local old=p.active.token; s:Request(raid(2734),{100}); p:Cancel(old)
expect(p.active and p.active.context.encounterID==2734,"old token cannot cancel replacement")
p,s=fixture()
for i=1,70 do s:Request(raid(3000+i),{100}) end
expect(#p.cacheOrder==64,"memory cache has bounded capacity")
p,s=fixture()
C_EncounterJournal.SetSlotFilter=function() error("restore exception") end
s:Request(raid(),{100})
expect(s.result.state=="failed" and s.result.reason=="journal-restore-failed" and
    s.difficulty==16 and s.classID==2 and s.specID==65,"restore exceptions retain failure and restore other fields")
p,s=fixture()
C_EncounterJournal.SetSlotFilter=function() end
s:Request(raid(),{100})
expect(s.result.reason=="journal-restore-failed","silent restore coercion is detected")
p,s=fixture(); s.missingLink=true; s:Request(raid(),{100})
for i=1,6 do s:Tick() end
p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001)
for i=1,6 do s:Tick() end
count=s.queries
for i=1,100 do p:OnEvent("EJ_LOOT_DATA_RECIEVED",1001); s:Tick() end
expect(s.queries==count and count==12,"late Journal recovery is also bounded")
p,s=fixture()
local replaced=false
s.onQuery=function()
    if not replaced then replaced=true; s:Request(raid(2734),{100}) end
end
s:Request(raid(),{100}); s:Tick()
expect(s.result.context.encounterID==2734 and s.result.state=="ready",
    "reentrant replacement waits for transaction and still completes")
p,s=fixture()
local murder=dungeon()
murder.instanceID,murder.journalInstanceID,murder.challengeModeID=2813,1304,587
murder.rewardSource.challengeModeID=587
s.validDifficulties={[1]=true,[2]=true,[23]=true}
s:Request(murder,{100})
expect(s.result.state=="ready" and s.queries==1 and #s.result.specs[100].items==2,
    "live Murder Row difficulty snapshot retrieves combined boss pool at 23")
local result=s.result.specs[100]
expect(result.journalDifficultyID==23 and result.items[1].encounterID==111 and
    result.items[2].encounterID==222 and s.result.context.lootMode=="mythic-plus",
    "Murder Row includes multiple bosses and preserves Mythic+ reward context")
s:Restored()
p,s=fixture(); s.bonusRow=2; s:Request(dungeon(),{100})
expect(s.result.state=="ready" and #s.result.specs[100].items==1,
    "dungeon pool excludes per-player bonus drops such as recipes")
p,s=fixture(); s.bonusRow=1; s:Request(raid(),{100})
expect(s.result.state=="ready" and #s.result.specs[100].items==1,
    "raid Journal bonus loot handling remains unchanged")
p,s=fixture(); s.stale=true; s:Request(raid(),{100})
expect(s.result.state=="ready" and #s.result.specs[100].items==1 and
    s.result.specs[100].completeness.journalOutOfDate,
    "Journal refresh flag does not veto fully populated item rows")
for i=1,8 do s:Tick() end
expect(s.result.state=="ready" and s.queries==1,"complete flagged rows never hit false timeout")
s:Restored()
p,s=fixture(); s.stale=true; s.missingRow=true; s:Request(raid(),{100})
expect(s.result.state=="loading" and s.result.specs[100].completeness.missingRows==1,
    "missing rows remain incomplete even with a refresh flag")
p,s=fixture(); s.stale=true; s.missingMetadata=true; s:Request(raid(),{100})
expect(s.result.state=="loading" and s.result.specs[100].completeness.missingNames==1 and
    s.result.specs[100].completeness.missingIcons==1,
    "missing names and icons still prevent completion")
s.itemReady=true; p:OnEvent("ITEM_DATA_LOAD_RESULT",1001,true)
expect(s.result.state=="ready" and s.result.specs[100].completeness.missingNames==0,
    "item completion updates completeness diagnostics")
p,s=fixture(); s.stale=true; s.missingLink=true; s:Request(raid(),{100})
expect(s.result.state=="loading" and s.result.specs[100].completeness.missingLinks==1,
    "missing links still prevent completion")
print("Passed "..checks.." loot provider checks")
