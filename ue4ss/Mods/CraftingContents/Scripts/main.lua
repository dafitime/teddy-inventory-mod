-- CraftingContents
-- Entry point / bootstrap only. Each feature lives in its own module file
-- and is loaded independently here, wrapped in pcall, so a bug in one
-- feature can't take down any of the others (or stop this file from
-- finishing loading at all).
--
-- Current features:
--   ConverterTooltips.lua - shows what's placed in a crafting/converter
--   station and what it'll produce, on hover. Stable and working.
--
-- Adding a new feature: put it in its own Scripts/<Name>.lua file (a
-- self-contained module, not dependent on anything in this file) and add
-- one LoadFeature("<Name>") line below. Never add feature logic directly
-- to this file.

print("[CraftingContents] mod loaded")

local function LoadFeature(name)
    local ok, err = pcall(require, name)
    if not ok then
        print("[CraftingContents] FAILED to load feature '" .. name .. "': " .. tostring(err))
    else
        print("[CraftingContents] loaded feature '" .. name .. "'")
    end
end

LoadFeature("ConverterTooltips")
