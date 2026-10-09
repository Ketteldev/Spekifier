local output = print
local fixture = assert(loadfile('spec/Modules/Context/AutoShow.lua'))()
local checks = 0
local function expect(v, label) assert(v, label); checks = checks + 1 end
local function setup(overrides, saved)
    local a, s, event = fixture(overrides, saved)
    local ids = { 71, 72, 73, 74 }
    function GetSpecializationInfo(i) if not s.missingSpecs then return ids[i], 'Spec ' .. i, nil, i end end
    for i, column in ipairs(a:GetAllSpecColumns()) do column.specID = ids[i] end
    s.lootSpec, s.activeSpec, s.calls = 71, 1, {}
    function GetLootSpecialization() if s.getterError then error('unavailable') end; return s.lootSpec end
    function GetSpecialization() return s.activeSpec end
    function SetLootSpecialization(id)
        s.calls[#s.calls + 1] = id
        if s.setterError then error('denied') end
        if not s.silent and not s.delayed then
            s.lootSpec = id
            a.lootSpecFrame:Fire('OnEvent', 'PLAYER_LOOT_SPEC_UPDATED')
        end
    end
    assert(loadfile("src/Modules/Loot/Selection.lua"))('Spekifier', { Spekifier = a })
    a:InitializeLootSpecialization()
    return a, s, event
end
for _, count in ipairs({2, 3, 4}) do
    local a,s = setup({numSpecs=count})
    local w, runtime = a:GetMainWindow(), a:GetWindowState()
    expect(runtime.confirmedSpecID == 71 and runtime.selectionAllowed, 'opening reads confirmed game state')
    for _, column in ipairs(a:GetAllSpecColumns()) do
        a:ShowWindow('manual')
        expect(a:HandleSpecColumnClick(column.specID, 'LeftButton'), 'column accepts valid click')
        expect(s.calls[#s.calls] == column.specID, 'setter receives stored ID rather than index')
        expect(runtime.confirmedSpecID == column.specID, 'synchronous update confirms selected marker')
        expect(not w:IsShown() and s.messages[#s.messages] == 'Spekifier has set your loot specialization to ' .. column.specName .. '.', 'selection closes with exact system confirmation')
        a:RefreshAutoShow(nil)
        expect(not w:IsShown(), 'confirmed selection suppresses automatic reopening')
    end
    a:ShowWindow('manual')
    local n = #s.calls
    a:GetSpecColumn(1).frame:Fire('OnEnter'); a:GetSpecColumn(1).frame:Fire('OnUpdate')
    expect(#s.calls == n, 'hover does not call setter')
    expect(not a:HandleSpecColumnClick(71, 'RightButton') and #s.calls == n, 'right click does not call setter')
    expect(not a:SelectLootSpecialization(999) and #s.calls == n, 'foreign ID rejected')
    s:Tick(); expect(runtime.selectionNotice == nil and runtime.confirmedSpecID ~= nil, 'brief notice expires but marker persists')
end
local a,s,event = setup()
local runtime,w = a:GetWindowState(),a:GetMainWindow()
local shows = w.showCount
s.lootSpec = 72; a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED')
expect(runtime.confirmedSpecID == 72 and w.showCount == shows, 'external changes update without reopening')
s.lootSpec = 0; s.activeSpec = 3; a.lootSpecFrame:Fire('OnEvent','PLAYER_SPECIALIZATION_CHANGED','player')
expect(runtime.confirmedSpecID == 73 and runtime.lootSpecSetting == 0, 'current specialization resolves active ID')
s.activeSpec = 2; a.lootSpecFrame:Fire('OnEvent','PLAYER_SPECIALIZATION_CHANGED','player')
expect(runtime.confirmedSpecID == 72, 'current setting tracks active changes')
s.lootSpec = 71; a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED'); s.activeSpec = 3
a.lootSpecFrame:Fire('OnEvent','PLAYER_SPECIALIZATION_CHANGED','player')
expect(runtime.confirmedSpecID == 71, 'explicit setting stays independent of active spec')
s.getterError = true; a:RefreshLootSpecialization()
expect(not runtime.selectionAllowed and runtime.confirmedSpecID == nil, 'unavailable getter fails closed')
s.getterError = false; a.lootSpecFrame:Fire('OnEvent','PLAYER_TALENT_UPDATE')
expect(runtime.selectionAllowed and runtime.confirmedSpecID == 71, 'talent event retries unavailable data')
s.silent = true; a:HandleSpecColumnClick(72,'LeftButton')
expect(runtime.confirmedSpecID == 71, 'silent setter never causes optimistic highlight')
s:Tick(); expect(runtime.confirmedSpecID == 71 and runtime.selectionNotice:find('not confirmed'), 'timeout preserves previous game state and explains failure')
s.silent = false; s.setterError = true
expect(not a:HandleSpecColumnClick(72,'LeftButton') and runtime.confirmedSpecID == 71 and runtime.selectionNotice:find('Unable'), 'setter exception preserves state and explains failure')
s.setterError = false; s.delayed = true; a:HandleSpecColumnClick(72,'LeftButton')
expect(runtime.confirmedSpecID == 71, 'delayed setter remains unconfirmed')
s.lootSpec = 72; a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED')
expect(runtime.confirmedSpecID == 72 and not w:IsShown() and s.messages[#s.messages] == 'Spekifier has set your loot specialization to Spec 2.', 'delayed event closes and reports confirmed choice')
local messages = #s.messages
a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED')
expect(#s.messages == messages, 'repeated confirmation event does not duplicate message')
for _, change in ipairs({{combat=true},{dead=true},{exists=false},{npcID=999},{npcID=244762},{difficultyID=15},{instanceType='none',inInstance=false}}) do
    a,s = setup()
    for k,v in pairs(change) do s[k]=v end
    expect(not a:HandleSpecColumnClick(72,'LeftButton') and #s.calls == 0, 'fresh click rejects changed combat/target/difficulty/instance')
end
a,s = setup({instanceType='party',difficultyID=23,exists=false})
expect(a:HandleSpecColumnClick(72,'LeftButton') and s.calls[1] == 72, 'dungeon selection needs neither target nor key')
a:ShowWindow('manual')
s.instanceID = 100
expect(not a:HandleSpecColumnClick(73,'LeftButton') and #s.calls == 1, 'different dungeon visit rejects stale click')
a,s = setup(nil,{enabled=false}); a:ShowWindow('manual')
expect(a:HandleSpecColumnClick(72,'LeftButton'), 'manual selection works with automatic opening disabled')
a:HideWindow('dismissed'); shows=a:GetMainWindow().showCount
s.lootSpec=73; a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED')
expect(not a:GetMainWindow():IsShown() and a:GetMainWindow().showCount==shows, 'external changes never reopen dismissed window')
a:ShowWindow('manual'); expect(a:GetWindowState().confirmedSpecID==73,'reopening reads external choice')
local f=a.lootSpecFrame; local registrations=f.registrations
a:InitializeLootSpecialization(); expect(a.lootSpecFrame==f and f.registrations==registrations,'initialization is idempotent')
output('Loot specialization: ' .. checks .. ' checks passed')
-- Retry missing specialization headers at the normal initialization event.
a,s = setup({numSpecs=0})
expect(#a:GetAllSpecColumns()==0,'no premature empty column registry')
s.numSpecs=3; a.lootSpecFrame:Fire('OnEvent','PLAYER_TALENT_UPDATE')
expect(#a:GetAllSpecColumns()==3,'late specialization data builds missing columns')
a,s = setup(); s.delayed=true; a:HandleSpecColumnClick(72,'LeftButton')
s.npcID=244762; a:RefreshAutoShow(nil,false)
s.lootSpec=72; a.lootSpecFrame:Fire('OnEvent','PLAYER_LOOT_SPEC_UPDATED')
expect(a:GetWindowState().selectionNotice==nil,'old request cannot confirm in new encounter')
a,s = setup(); s.delayed=true; a:HandleSpecColumnClick(72,'LeftButton'); a:HideWindow('dismissed')
s:Tick(); expect(a:GetWindowState().selectionNotice==nil,'old timers cannot restore notices after closing')
output('Loot specialization total: ' .. checks .. ' checks passed')
a,s = fixture({selectionModule=true})
expect(a.lootSpecFrame~=nil and a:GetWindowState().confirmedSpecID==1 and a:GetWindowState().selectionAllowed,'production login initializes selection before interaction')
a:GetSpecColumn(2).frame:Fire('OnClick','LeftButton')
expect(s.lootSpec==2 and a:GetWindowState().confirmedSpecID==2,'production frame click reaches confirmed setter')
output('Loot specialization final: ' .. checks .. ' checks passed')
a,s = setup(); local setter=SetLootSpecialization; SetLootSpecialization=nil; a:RefreshLootSpecialization()
expect(not a:GetWindowState().selectionAllowed and not a:HandleSpecColumnClick(72,'LeftButton'),'missing setter disables selection')
SetLootSpecialization=setter; s.lootSpec=999; a:RefreshLootSpecialization()
expect(a:GetWindowState().confirmedSpecID==nil and not a:GetWindowState().selectionAllowed,'foreign getter ID fails closed')
s.lootSpec=72; a.lootSpecFrame:Fire('OnEvent','PLAYER_SPECIALIZATION_CHANGED','party1')
expect(a:GetWindowState().confirmedSpecID==nil,'non-player specialization event ignored')
a.lootSpecFrame:Fire('OnEvent','PLAYER_ENTERING_WORLD')
expect(a:GetWindowState().confirmedSpecID==72,'world entry retries valid game state')
output('Loot specialization: ' .. checks .. ' focused checks passed')
