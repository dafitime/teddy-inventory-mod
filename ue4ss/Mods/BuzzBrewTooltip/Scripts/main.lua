-- BuzzBrewTooltip
-- A genuinely separate mod from CraftingContents - not just a separate file
-- in the same Scripts folder. EnableAutoReloadingLuaMods watches an entire
-- Scripts directory, not individual files, so editing ANY file in
-- CraftingContents/Scripts/ (even one main.lua doesn't require) triggers a
-- full reload of that mod too. Being a separate mod with its own Scripts
-- folder means this can be edited/reloaded/broken freely without ever
-- touching CraftingContents, which stays untouched and stable.
--
-- Fully self-contained on purpose (its own copy of display-name resolution
-- below, not shared with CraftingContents) - for the same isolation reason.
--
-- What this does: shows what's placed in the BuzzBrew honey/buzz brewing
-- station on hover, and what it'll produce - the one station
-- CraftingContents' ConverterTooltips deliberately skips, since its Helper
-- popup only ever rendered once per session no matter what was written to
-- it under the normal per-tick polling approach every other station uses.
--
-- The fix: BP_Converter_BuzzBrew_C uniquely overrides
-- HighlightItem(UPrimitiveComponent*), which fires reliably on every single
-- hover (confirmed via diagnostic logging). Forcing the popup visible and
-- updating its text only inside that hook - not a timer poll - means there's
-- no "stuck on forever" risk, since the hook only runs while a hover is
-- actually happening.

print("[BuzzBrewTooltip] mod loaded")

local UEHelpers = require("UEHelpers")
local KismetTextLibrary = UEHelpers.GetKismetTextLibrary()

local function FNameToString(fname)
    local ok, s = pcall(function() return tostring(fname:ToString()) end)
    return ok and s or nil
end

local function Humanize(tag)
    local s = tag:gsub("_", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    return s
end

-- Same baked tag -> display name table as CraftingContents' DisplayNames
-- module, duplicated here rather than shared, for isolation.
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

local function DisplayName(tag)
    if tag == nil then return nil end
    return DisplayNameCache[tag] or Humanize(tag)
end

local OriginalText = {}
local PlacedItemCache = {}

local function HandleTagCaptured(selfObj, tagParam)
    local okSelf, key = false, nil
    if selfObj ~= nil then
        okSelf, key = pcall(function() return selfObj:GetFullName() end)
    end
    if not okSelf or key == nil then return end

    local okTag, tagVal = pcall(function() return tagParam:get() end)
    if not okTag or tagVal == nil then return end

    local tagStr = FNameToString(tagVal)
    if tagStr ~= nil and tagStr ~= "" and tagStr ~= "None" then
        PlacedItemCache[key] = tagStr
    end
end

-- BuzzBrew takes TWO ingredients: honey (base class AmountInside/MaxAmount/
-- WhatCanBePlaced) and fruit (BuzzBrew's own FruitAmountInside/
-- FruitMaxAmountInside/AddedFruit). Both amounts are read and shown
-- together rather than one replacing the other.
local function GetItemLabel(converter)
    local convKey = converter:GetFullName()

    local okHoneyAmt, honeyAmt = pcall(function() return converter.AmountInside end)
    honeyAmt = (okHoneyAmt and honeyAmt) or 0
    local okHoneyMax, honeyMax = pcall(function() return converter.MaxAmount end)
    honeyMax = okHoneyMax and honeyMax or nil

    local honeyTag = PlacedItemCache[convKey]
    local honeyIsFallbackCategory = false
    if honeyTag == nil then
        local ok, whatCanBePlaced = pcall(function() return converter.WhatCanBePlaced end)
        if ok and whatCanBePlaced ~= nil then
            honeyTag = FNameToString(whatCanBePlaced)
            honeyIsFallbackCategory = true
        end
    end

    local okFruitAmt, fruitAmt = pcall(function() return converter.FruitAmountInside end)
    fruitAmt = (okFruitAmt and fruitAmt) or 0
    local okFruitMax, fruitMax = pcall(function() return converter.FruitMaxAmountInside end)
    fruitMax = okFruitMax and fruitMax or nil

    local okFruitTag, fruitTagRaw = pcall(function() return converter.AddedFruit end)
    local fruitTag = (okFruitTag and fruitTagRaw ~= nil) and FNameToString(fruitTagRaw) or nil

    if honeyAmt <= 0 and fruitAmt <= 0 then
        return nil -- nothing placed at all
    end

    local parts = {}
    local fruitName = nil

    if honeyAmt > 0 and honeyTag ~= nil and honeyTag ~= "" and honeyTag ~= "None" then
        -- WhatCanBePlaced on BuzzBrew is a broad acceptance category, not
        -- the specific honey item, whenever the specific placement tag
        -- wasn't captured this session (via PlacedItemCache). Whatever
        -- that fallback tag's exact spelling is, showing it humanized
        -- ("Fruit And Honey" or similar) is confusing - just call it
        -- "Honey" any time we're in the fallback path, regardless of the
        -- tag's exact text.
        local honeyName = honeyIsFallbackCategory and "Honey" or DisplayName(honeyTag)
        if honeyMax ~= nil and honeyMax > 0 then
            table.insert(parts, string.format("%s %d/%d", honeyName, honeyAmt, honeyMax))
        else
            table.insert(parts, string.format("%s x%d", honeyName, honeyAmt))
        end
    end

    if fruitAmt > 0 and fruitTag ~= nil and fruitTag ~= "" and fruitTag ~= "None" then
        fruitName = DisplayName(fruitTag)
        if fruitMax ~= nil and fruitMax > 0 then
            table.insert(parts, string.format("%s %d/%d", fruitName, fruitAmt, fruitMax))
        else
            table.insert(parts, string.format("%s x%d", fruitName, fruitAmt))
        end
    end

    local label = table.concat(parts, " + ")
    if label == "" then
        label = string.format("Unknown x%d", math.max(honeyAmt, fruitAmt))
    end

    -- Output naming pattern confirmed from the baked table
    -- (BuzzBrew_FreshBlueberry -> "Azureberry Buzz") and live testing
    -- (Emberberry -> "Emberberry Buzz"): the fruit's own display name with
    -- " Buzz" appended, once fruit has actually been added.
    if fruitName ~= nil then
        return label .. ". Will make " .. fruitName .. " Buzz. Placed in storage the next day."
    end

    return label
end

local function ForceShowAndUpdate(helper, fieldName, itemLabel)
    local textBlock = helper[fieldName]
    if textBlock == nil or not textBlock:IsValid() then return end

    local key = fieldName
    if OriginalText[key] == nil then
        local ok, currentText = pcall(function()
            return KismetTextLibrary:Conv_TextToString(textBlock:GetText()):ToString()
        end)
        OriginalText[key] = ok and currentText or ""
    end

    local newText = itemLabel ~= nil and itemLabel or OriginalText[key]
    pcall(function()
        textBlock:SetText(KismetTextLibrary:Conv_StringToText(newText))
    end)
end

-- Unconditional every call, no throttling, no IsRendered() check - this is
-- the shape confirmed working reliably across repeat hovers.
local function OnHighlightItem(Context, _Component)
    local okSelf, converter = pcall(function() return Context:get() end)
    if not okSelf or converter == nil or not converter:IsValid() then return end

    local okLabel, itemLabel = pcall(GetItemLabel, converter)
    if not okLabel then itemLabel = nil end

    local okHelper, helper = pcall(function() return converter.Help end)
    if not okHelper or helper == nil or not helper:IsValid() then return end

    pcall(function() helper:SetVisibility(0) end) -- 0 = Visible
    pcall(function() helper:AddToViewport(9999) end)

    -- Writing to both T_ItemName_3 and T_ItemName caused a visible
    -- duplicate (two tooltips on screen at once - one middle-left, one
    -- bottom-left). T_ItemName_3 is the field every other station's Helper
    -- uses and is the one in the correct (bottom-left) position, so only
    -- that one gets updated now. T_ItemName is left completely alone.
    pcall(ForceShowAndUpdate, helper, "T_ItemName_3", itemLabel)
end

-- RegisterHook can silently fail if it runs before the target Blueprint
-- class is actually loaded into memory - confirmed by testing, this can
-- happen as little as ~11 seconds after UE4SS starts, producing ZERO
-- working hooks for the whole session with no error at all. So registration
-- isn't a single attempt: tried once immediately (best effort, may be too
-- early), then retried once more automatically as soon as a LIVE
-- BP_Converter_BuzzBrew_C instance is actually found - which by definition
-- means the class is loaded, so that attempt is reliable.
local function RegisterAllHooks()
    pcall(function()
        RegisterHook("/Game/Interactive/Shop/Production/BP_Converter_BuzzBrew.BP_Converter_BuzzBrew_C:HandlePlaceItem",
            function(Context, ComplexDataTable)
                local okSelf, selfObj = pcall(function() return Context:get() end)
                HandleTagCaptured(okSelf and selfObj or nil, ComplexDataTable)
            end)
    end)

    pcall(function()
        RegisterHook("/Game/Interactive/Shop/Production/BP_Converter_BuzzBrew.BP_Converter_BuzzBrew_C:HandleReloadSave",
            function(Context, ItemPlacedAdvance, _AmountInside)
                local okSelf, selfObj = pcall(function() return Context:get() end)
                HandleTagCaptured(okSelf and selfObj or nil, ItemPlacedAdvance)
            end)
    end)

    pcall(function()
        RegisterHook(
            "/Game/Interactive/Shop/Production/BP_Converter_BuzzBrew.BP_Converter_BuzzBrew_C:HighlightItem",
            OnHighlightItem
        )
    end)
end

RegisterAllHooks() -- eager, best-effort, first attempt

local RetryDone = false
LoopAsync(500, function()
    if RetryDone then return true end
    local ok, converters = pcall(FindAllOf, "BP_Converter_BuzzBrew_C")
    if ok and converters ~= nil and next(converters) ~= nil then
        RetryDone = true
        pcall(RegisterAllHooks)
        return true
    end
    return false
end)

print("[BuzzBrewTooltip] hooks registered")
