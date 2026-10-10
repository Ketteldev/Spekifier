-- Run from the repository root: lua5.1 spec/run_tests.lua
-- Requires Lua 5.1 and LuaFileSystem (luarocks install luafilesystem).
assert(_VERSION == "Lua 5.1", "Tests require Lua 5.1, matching the addon runtime")
assert(not arg or not arg[1], "Usage: lua5.1 spec/run_tests.lua; use scripts/package.lua for ZIPs")
local lfs = require("lfs")
local function files(directory, result)
    result = result or {}
    for name in lfs.dir(directory) do
        if name ~= "." and name ~= ".." then
            local path = directory .. "/" .. name
            if lfs.attributes(path, "mode") == "directory" then
                files(path, result)
            elseif name:match("%.lua$") then
                result[#result + 1] = path
            end
        end
    end
    table.sort(result)
    return result
end
local expected = {

        'Core/Init.lua',
        'Core/Database.lua',
        'Core/Debug.lua',
        'Core/Events.lua',
        'Modules/Context/RaidCatalog.lua',
        'Modules/Context/Resolver.lua',
        'Modules/Loot/Model.lua',
        'Modules/Loot/Provider.lua',
        'Modules/Loot/Journal.lua',
        'Modules/Loot/Events.lua',
        'Modules/Loot/Selection.lua',
        'Modules/Loot/RequestIdentity.lua',
        'Modules/Loot/Diagnostics.lua',
        'UI/Skins/Registry.lua',
        'UI/Skins/Palettes.lua',
        'UI/Skins/Presentation.lua',
        'UI/Options/SkinDropdown.lua',
        'UI/Options/Panel.lua',
        'UI/Minimap.lua',
        'UI/Window/Lifecycle.lua',
        'UI/Window/LootBinding.lua',
        'UI/Window/Fit.lua',
        'UI/Window/Layout.lua',
        'UI/Loot/Tooltips.lua',
        'UI/Loot/DisplayLists.lua',
        'UI/Loot/SharedRow.lua',
        'UI/Loot/ItemRows.lua',
        'UI/Loot/Columns.lua',
        'UI/Loot/Renderer.lua',
        'Modules/Commands.lua',
        'Modules/Context/AutoShow.lua',
}
local runtime, registered = {}, {}
for line in io.lines("src/Spekifier.toc") do
    local path = line:match("^%s*(.-%.lua)%s*$")
    if path then
        path = path:gsub("\\", "/")
        assert(not registered[path], "Duplicate manifest file: " .. path)
        runtime[#runtime + 1], registered[path] = path, true
    end
end
assert(#runtime == #expected, "Unexpected manifest file count")
for index, path in ipairs(expected) do
    assert(runtime[index] == path, "Unexpected manifest load order at " .. index .. ": " .. path)
end
for _, directory in ipairs({ "Core", "Modules", "UI" }) do
    for _, path in ipairs(files("src/" .. directory)) do
        assert(registered[path:sub(5)], "Unregistered runtime file: " .. path)
    end
end
for _, directory in ipairs({ "src", "spec", "scripts" }) do
    for _, path in ipairs(files(directory)) do assert(loadfile(path)) end
end

-- Each suite gets fresh globals and standard-library tables. Nested dofile and
-- loadfile calls share that suite's environment, preserving the fixture mocks.
local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do copy[key] = clone(entry, seen) end
    return copy
end
local function environment()
    local env = clone(_G)
    env._G = env
    env.loadfile = function(path)
        local chunk, message = loadfile(path)
        if chunk then setfenv(chunk, env) end
        return chunk, message
    end
    env.dofile = function(path) return assert(env.loadfile(path))() end
    return env
end
local suites = {

    'Modules/Context/AutoShow.lua',
    'Modules/Loot/Provider.lua',
    'UI/Window/LootBinding.lua',
    'UI/Loot/Renderer.lua',
    'UI/Loot/SharedRow.lua',
    'Modules/Loot/Selection.lua',
    'UI/Options/Panel.lua',
    'Integration.lua',
    'Modules/Context/AutoShowPreferences.lua',
    'UI/Skins/Presentation.lua',
    'Manifest.lua',
}
for _, name in ipairs(suites) do
    print("Running " .. name)
    environment().dofile("spec/" .. name)
end
print("All eleven suites, Lua 5.1 syntax and manifest checks passed.")
