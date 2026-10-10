-- Core/Init.lua
-- Initialize the add-on namespace and main frame

local addonName, addonTable = ...

-- Create main add-on object
local Spekifier = {}
addonTable.Spekifier = Spekifier

-- Create the main event frame
Spekifier.frame = CreateFrame("Frame")

-- Export to global namespace for easy access
_G.Spekifier = Spekifier

-- Return the namespace
return addonName, addonTable
