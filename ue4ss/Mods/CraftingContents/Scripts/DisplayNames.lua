-- DisplayNames
-- Shared tag -> real display name resolution, used by both
-- ConverterTooltips.lua and BuzzBrewTooltip.lua so there's a single source
-- of truth for the name table instead of duplicate copies that could drift
-- out of sync.
--
-- The dev's internal codename for an item (e.g. "FreshBlueberry") isn't the
-- polished display name the player sees ("Azureberry"). The baked table
-- below was harvested from a manual sweep through every Storage category.
-- Not exhaustive - new items, and anything not yet seen in Storage, fall
-- back to the humanized tag until learned live via ScanStorageWidgets.

local UEHelpers = require("UEHelpers")
local KismetTextLibrary = UEHelpers.GetKismetTextLibrary()

local M = {}

local DisplayNameCache = {
    ["Wool_Sheep02"] = "Tan Whisperwool",
    ["JamGooseberryS"] = "Tigermelon Jam",
    ["JamCurrant"] = "Nightshade Jam",
    ["RawGold"] = "Sunglow Ore",
    ["RawSylvirite"] = "Sylvirite Ore",
    ["JamGooseberry"] = "Skydrop Jam",
    ["RawAmber"] = "Honeyglow Shard",
    ["RefinedDragonBlood"] = "Dragon's Blood Droplet",
    ["Powder_StegoScale"] = "Radiant Powder",
    ["FreshBlueberryS"] = "Nightblush Berry",
    ["RefinedWhy"] = "Chromaflux",
    ["JamAppleSp"] = "Greenwhistle Apple Jam",
    ["RawWhy"] = "Outofboundium",
    ["AriRaptorScale"] = "Brilliant Scale",
    ["StegoScale"] = "Radiant Scale",
    ["AetherBlueSky"] = "Blue Sky Aether",
    ["RawManacite"] = "Manacite Ore",
    ["JamCurrantS"] = "Velvenight Jam",
    ["ChickenEgg"] = "Dawnfeather Egg",
    ["BasicCheese"] = "Wheel of Braun Cheese",
    ["RawStarshard"] = "Starshard",
    ["FreshApple"] = "Sunapple",
    ["Sylvirite"] = "Refined Sylvirite",
    ["JamRaspberry"] = "Emberberry Jam",
    ["SeedBag_Cabbage01"] = "Emeraldleaf Seed",
    ["Gold"] = "Refined Sunglow",
    ["RawCopper"] = "Amberroot Ore",
    ["BuzzBrew_FreshBlueberry"] = "Azureberry Buzz",
    ["JamStrawberry"] = "Ghost Berry Jam",
    ["RefinedTitanite"] = "Fernbrite Leaf",
    ["Spun_Sheep04"] = "Brown Whisperthread",
    ["BuzzBrew_NoMix"] = "Classic Buzz",
    ["FreshPeachR"] = "Royale Peach",
    ["FreshAppleSp"] = "Greenwhistle Apple",
    ["RefinedLunacite"] = "Lunareth",
    ["Umbracite"] = "Refined Umbracite",
    ["Powder_Cinderscale"] = "Cinder Powder",
    ["RawTin"] = "Pebblebrite Ore",
    ["JamCranberry"] = "Bloodberry Jam",
    ["RawDragonsBlood"] = "Dragon's Blood Shard",
    ["Fur_Rabbit01"] = "Wimbletuft",
    ["RawSilver"] = "Starpebble Ore",
    ["RawAmethyst"] = "Lavendrite Shard",
    ["Silver"] = "Refined Starpebble",
    ["FreshCurrant"] = "Nightshade Berry",
    ["Wool_Sheep03"] = "Black Whisperwool",
    ["Sangrylith"] = "Refined Sangrylith",
    ["RaptorScale"] = "Sorelleon Scale",
    ["JamBlueberry"] = "Azureberry Jam",
    ["Fur_Rabbit02"] = "Jaspertuft",
    ["RefinedAmber"] = "Honeyglow Gem",
    ["FreshStrawberry"] = "Ghost Berry",
    ["Manacite"] = "Refined Manacite",
    ["FreshBlueberry"] = "Azureberry",
    ["RawTitanite"] = "Fernbrite Shard",
    ["RawUmbracite"] = "Umbracite Ore",
    ["FreshCurrantS"] = "Velvenight Berry",
    ["PotHoney1"] = "Pot of Bumblebuzz Honey",
    ["Fur_Rabbit03"] = "Mapletuft",
    ["Wool_Sheep04"] = "Brown Whisperwool",
    ["RawSangrylith"] = "Sangrylith Ore",
    ["JamPeachR"] = "Royale Peach Jam",
    ["Fur_Fox01"] = "Embertuft",
    ["Wool_Sheep01"] = "White Whisperwool",
    ["CowsMilk"] = "Eldermilk",
    ["Spun_Sheep02"] = "Tan Whisperthread",
    ["FreshStrawberryS"] = "Solberry",
    ["FreshGooseberry"] = "Skydrop Berry",
    ["FreshGooseberryS"] = "Tigermelon",
    ["Fish_Koi_Sp"] = "Mirei Sylphae",
    ["Axe01"] = "Stonecleaver",
    ["Tin"] = "Refined Pebblebrite",
    ["JamBlueberryS"] = "Nightblush Jam",
    ["FreshCranberryS"] = "Honeycran Berry",
    ["Stone"] = "Stone",
    ["Fur_Fox02"] = "Ahriatuft",
    ["CinderScale"] = "Cinder Scale",
    ["AetherStarshard"] = "Starshard Aether",
    ["Spun_Fox02"] = "Ahriathread",
    ["RefinedBlueSky"] = "Blue Sky Star",
    ["RawLunacite"] = "Lunacite Shard",
    ["RawBlueSky"] = "Blue Sky Shard",
    ["FreshRaspberry"] = "Emberberry",
    ["Powder_AriRaptorScale"] = "Brilliant Powder",
    ["JamRaspberryS"] = "Heartgleam Jam",
    ["FreshRaspberryS"] = "Heartgleam",
    ["Copper"] = "Refined Amberroot",
}

-- Deliberately written one folder ABOVE Scripts/ (the mod's own root
-- folder), not next to this file - EnableAutoReloadingLuaMods watches the
-- Scripts directory specifically ("reload triggers when any file is edited
-- or a new file is added to the 'Scripts' directory"), so writing the cache
-- file inside Scripts/ would silently trigger a full mod reload every
-- single time a new name is learned, wiping every feature's in-memory
-- state right along with it.
local function GetModRootDir()
    local ok, src = pcall(function() return debug.getinfo(1, "S").source end)
    if not ok or src == nil then return nil end
    local path = src:match("^@(.*)$") or src
    local scriptDir = path:match("^(.*)[/\\][^/\\]*$")
    if scriptDir == nil then return nil end
    return scriptDir:match("^(.*)[/\\][^/\\]*$")
end

local ModRootDir = GetModRootDir()
local DisplayNameCacheFilePath = ModRootDir and (ModRootDir .. "/display_names_cache.txt") or "display_names_cache.txt"

local function LoadDisplayNameCache()
    local ok, f, err = pcall(io.open, DisplayNameCacheFilePath, "r")
    if not ok or f == nil then
        print("[CraftingContents] no existing display name cache to load (" .. tostring(err) .. ")")
        return
    end
    local count = 0
    for line in f:lines() do
        local tag, name = line:match("^([^\t]*)\t(.*)$")
        if tag ~= nil and tag ~= "" and name ~= nil then
            DisplayNameCache[tag] = name
            count = count + 1
        end
    end
    f:close()
    print("[CraftingContents] loaded " .. count .. " cached display names")
end

local function SaveDisplayNameCache()
    local ok, f, err = pcall(io.open, DisplayNameCacheFilePath, "w")
    if not ok or f == nil then
        print("[CraftingContents] failed to save display name cache: " .. tostring(err))
        return
    end
    local count = 0
    for tag, name in pairs(DisplayNameCache) do
        f:write(tag .. "\t" .. name .. "\n")
        count = count + 1
    end
    f:close()
    print("[CraftingContents] saved " .. count .. " display names to cache file")
end

LoadDisplayNameCache()

-- "FreshBlueberry" -> "Fresh Blueberry" (fallback for tags we can't resolve
-- to a real display name yet).
function M.Humanize(tag)
    local s = tag:gsub("_", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    return s
end

function M.DisplayName(tag)
    if tag == nil then return nil end
    return DisplayNameCache[tag] or M.Humanize(tag)
end

local function TextToString(ftext)
    local ok, s = pcall(function() return KismetTextLibrary:Conv_TextToString(ftext):ToString() end)
    return ok and s or nil
end

function M.FNameToString(fname)
    local ok, s = pcall(function() return tostring(fname:ToString()) end)
    return ok and s or nil
end

-- Scans any currently-live W_Storage_Items widgets (populated whenever the
-- Storage screen is open) and harvests their already-resolved tag->name
-- mappings into our own cache, so we don't need to re-derive the lookup.
-- Struct_Item_Base is a Blueprint "UserDefinedStruct" - its members get a
-- GUID suffix baked into the real identifier, so "Name" (the clean label
-- shown in the header/editor) is actually "Name_13_8EC6574D...". Likewise
-- the widget's own field names ("Simple Data Table Entry", "Out Row") turned
-- out to literally contain spaces - confirmed via property enumeration.
local NAME_FIELD = "Name_13_8EC6574D44A2F1C8A6F453871D55233C"
local RowPairs = {
    { "Simple Data Table Entry", "Out Row" },
    { "Complex_DataTableEntry", "Out Row_0" },
}

function M.ScanStorageWidgets()
    local ok, widgets = pcall(FindAllOf, "W_Storage_Items_C")
    if not ok or widgets == nil then return end

    local learnedAny = false

    for _, w in pairs(widgets) do
        if w:IsValid() then
            for _, pair in ipairs(RowPairs) do
                local okTag, tag = pcall(function() return w[pair[1]] end)
                if okTag and tag ~= nil then
                    local tagStr = M.FNameToString(tag)
                    if tagStr ~= nil and tagStr ~= "" and tagStr ~= "None" and DisplayNameCache[tagStr] == nil then
                        local okRow, row = pcall(function() return w[pair[2]] end)
                        if okRow and row ~= nil then
                            local okRowName, rowName = pcall(function() return row[NAME_FIELD] end)
                            if okRowName and rowName ~= nil then
                                local nameStr = TextToString(rowName)
                                if nameStr ~= nil and nameStr ~= "" then
                                    DisplayNameCache[tagStr] = nameStr
                                    learnedAny = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if learnedAny then
        pcall(SaveDisplayNameCache)
    end
end

return M
