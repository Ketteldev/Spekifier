-- Spekifier.lua
-- Main entry point for the Spekifier add-on
-- This file is loaded last after all other components

local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier

-- Add-on is now fully loaded and ready
-- All initialization is handled through the event system in Core/Events.lua