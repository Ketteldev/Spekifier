-- Usage: lua scripts/package.lua [output.zip]
-- Lua 5.1+ launcher: Windows PowerShell or Linux sh + zip performs compression.
-- No Lua modules or Python are needed. Paths are relative to the caller's cwd.
local function fail(message)
    io.stderr:write(message, "\n")
    os.exit(1)
end

if not arg or not arg[0] or arg[2] then
    fail("Usage: lua scripts/package.lua [output.zip]")
end
local windows = package.config:sub(1, 1) == "\\"
local directory = arg[0]:match("^(.*[/\\])") or "./"
local command
if windows then
    -- Numeric UTF-8 bytes keep path text out of both cmd.exe and PowerShell
    -- syntax, including quotes, percent signs, and shell metacharacters.
    local function pathExpression(path)
        local bytes = {}
        for i = 1, #path do bytes[i] = tostring(path:byte(i)) end
        return "([Text.Encoding]::UTF8.GetString([byte[]](" .. table.concat(bytes, ",") .. ")))"
    end
    command = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& '
        .. pathExpression(directory .. "package.ps1")
    if arg[1] then
        if arg[1] == "" then fail("Output path must not be empty.") end
        command = command .. " -OutputPath " .. pathExpression(arg[1])
    end
    command = command .. '"'
else
    local function quote(value)
        return "'" .. value:gsub("'", "'\"'\"'") .. "'"
    end
    command = "sh " .. quote(directory .. "package.sh")
    if arg[1] then
        if arg[1] == "" then fail("Output path must not be empty.") end
        command = command .. " " .. quote(arg[1])
    end
end
local status = os.execute(command)
-- Lua 5.1 returns a numeric status; later Lua versions return true on success.
if status ~= true and status ~= 0 then
    fail("Release packaging failed; see the platform packager's error above.")
end
