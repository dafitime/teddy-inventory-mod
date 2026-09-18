-- ConverterTooltips
-- Appends the currently-placed item's name/amount, and what it will turn
-- into, to the crafting station "Helper" tooltip popup (the panel that
-- shows directions when you hover a converter/refining station).
--
-- This is the stable, working feature - kept in its own module (separate
-- from main.lua) so any future feature can be added as its own independent
-- module without risking this one. See main.lua for how modules are loaded.
--
-- How it works:
--   Every BP_Converter_* station (Furnace, BuzzBrew, Cheese, Crusher, Crystal,
--   Yarn, Jammer, ...) extends BP_Converter_Base and tracks AmountInside, but
--   the specific item placed isn't reliably readable afterward (LastPlacedItem
--   goes stale, GetCurrentItemsPlaced comes back empty, etc). So instead we
--   hook HandlePlaceItem/HandleReloadSave on each converter class and capture
--   the item's internal FName tag (e.g. "FreshBlueberry") at the moment it's
--   actually given to the station.
--
--   That tag is the dev's internal codename, not the polished display name
--   the player sees ("Azureberry"). To resolve the real name, we scan any
--   currently-open W_Storage_Items widgets (the Storage screen) - each one
--   already did a DataTable lookup from tag -> Struct_Item_Base (a row with
--   a real display-name field). We just read what it already computed.
--
--   To find out what a station will actually produce, we read each
--   converter class's own PlacedItemDataTableEntry_Transitions map (input
--   tag -> Struct_ProducerSettings, which has the output tag + max amount).
--
--   Each station also owns a "Helper" widget (its on-hover popup) with a
--   T_ItemName_3 text field we append our info to.

local UEHelpers = require("UEHelpers")
local KismetTextLibrary = UEHelpers.GetKismetTextLibrary()
local DisplayNames = require("DisplayNames")

local DEBUG = false
local DebugLoggedKeys = {}
local function DebugOnce(key, msg)
    if DEBUG and not DebugLoggedKeys[key] then
        DebugLoggedKeys[key] = true
        print("[CraftingContents] " .. msg .. "\n")
    end
end

local OriginalText = {}
local PlacedItemCache = {}
local HookedClasses = {}
local RecipeCache = {}

local function HandleTagCaptured(selfObj, tagParam, source)
    local okSelf, key = false, nil
    if selfObj ~= nil then
        okSelf, key = pcall(function() return selfObj:GetFullName() end)
    end
    if not okSelf or key == nil then return end

    local okTag, tagVal = pcall(function() return tagParam:get() end)
    if not okTag or tagVal == nil then return end

    local tagStr = DisplayNames.FNameToString(tagVal)
    if tagStr ~= nil and tagStr ~= "" and tagStr ~= "None" then
        PlacedItemCache[key] = tagStr
        DebugOnce(key .. "|" .. source .. "|cached", source .. " cached '" .. tagStr .. "' for " .. key)
    end
end

-- Struct_ProducerSettings is also a Blueprint UserDefinedStruct, so its
-- fields need their GUID-suffixed real names too.
local CHANGESTO_FIELD = "ChangesTo_6_5843D5444887B0E2FCAD858BA61AC98D"
local MAXIN_FIELD = "MaxAmountInProducer_7_F50E65BB41255EDB792D8198F1D5C67B"
local MAXPRODUCED_FIELD = "MaxAmountProduced_10_12B3D63647CE4F965591208D89362C01"

-- PlacedItemDataTableEntry_Transitions (TMap<FName, Struct_ProducerSettings>)
-- is a Blueprint-authored constant, identical across every instance of a
-- given converter class, so we only need to read it once per class.
local function BuildRecipeCache(converter)
    local okClass, classObj = pcall(function() return converter:GetClass() end)
    if not okClass or classObj == nil then return end
    local okName, classFullName = pcall(function() return classObj:GetFullName() end)
    if not okName or classFullName == nil then return end
    if RecipeCache[classFullName] ~= nil then return end

    local recipes = {}
    RecipeCache[classFullName] = recipes -- set immediately so we don't retry every tick

    local ok, map = pcall(function() return converter.PlacedItemDataTableEntry_Transitions end)
    if not ok or map == nil then return end

    pcall(function()
        map:ForEach(function(key, value)
            local okKeyVal, keyVal = pcall(function() return key:get() end)
            if not okKeyVal or keyVal == nil then return end
            local keyStr = DisplayNames.FNameToString(keyVal)
            if keyStr == nil or keyStr == "" or keyStr == "None" then return end

            local okValueVal, valueVal = pcall(function() return value:get() end)
            if not okValueVal or valueVal == nil then return end

            local okCT, ct = pcall(function() return valueVal[CHANGESTO_FIELD] end)
            local changesTo = (okCT and ct ~= nil) and DisplayNames.FNameToString(ct) or nil

            local okMaxIn, maxIn = pcall(function() return valueVal[MAXIN_FIELD] end)
            local okMaxOut, maxOut = pcall(function() return valueVal[MAXPRODUCED_FIELD] end)

            recipes[keyStr] = {
                changesTo = changesTo,
                maxIn = okMaxIn and maxIn or nil,
                maxProduced = okMaxOut and maxOut or nil,
            }
        end)
    end)
end

local function GetRecipeInfo(converter, inputTag)
    local okClass, classObj = pcall(function() return converter:GetClass() end)
    if not okClass or classObj == nil then return nil end
    local okName, classFullName = pcall(function() return classObj:GetFullName() end)
    if not okName or classFullName == nil then return nil end
    local recipes = RecipeCache[classFullName]
    if recipes == nil then return nil end
    return recipes[inputTag]
end

local function RegisterHooksForAssetPath(assetPath)
    if HookedClasses[assetPath] then return end
    HookedClasses[assetPath] = true

    pcall(function()
        RegisterHook(assetPath .. ":HandlePlaceItem", function(Context, ComplexDataTable)
            local okSelf, selfObj = pcall(function() return Context:get() end)
            HandleTagCaptured(okSelf and selfObj or nil, ComplexDataTable, "HandlePlaceItem")
        end)
    end)

    pcall(function()
        RegisterHook(assetPath .. ":HandleReloadSave", function(Context, ItemPlacedAdvance, _AmountInside)
            local okSelf, selfObj = pcall(function() return Context:get() end)
            HandleTagCaptured(okSelf and selfObj or nil, ItemPlacedAdvance, "HandleReloadSave")
        end)
    end)
end

-- HandleReloadSave is meant to tell us which specific item is ALREADY in a
-- station at save-load time - but that only works if the hook is registered
-- before it fires. The old approach only registered hooks once a LIVE
-- instance of a class was found via FindAllOf, inside the polling loop -
-- which only starts ticking after the whole script finishes loading. If
-- HandleReloadSave fires during level load (very likely, since it's a
-- reload-time event), we'd miss it forever for every station that already
-- had something placed, and permanently fall back to the generic category
-- ("Fruit x12" instead of the real item). So every known converter class is
-- hooked immediately here, at script load time, before the game has had any
-- chance to fire these events - not deferred until we happen to see a live
-- instance. TryHookClass (used in the polling loop below) still exists as a
-- fallback for any converter class not in this list, in case the dev adds a
-- new one - it just won't catch that specific class's reload-save event on
-- THIS boot, only from the next one after it's added here.
local KNOWN_CONVERTER_CLASS_NAMES = {
    "BP_Converter_Base",
    "BP_Converter_Furnace",
    "BP_Converter_Jammer",
    "BP_Converter_Cheese",
    "BP_Converter_Crusher",
    "BP_Converter_Crystal",
    "BP_Converter_Crystal_Infusion",
    "BP_Converter_BuzzBrew",
    "BP_Converter_Yarn",
    "BP_Converter_Farming",
    "BP_Converter_Farming_01",
    "BP_Converter_Farming_05",
}

for _, className in ipairs(KNOWN_CONVERTER_CLASS_NAMES) do
    RegisterHooksForAssetPath("/Game/Interactive/Shop/Production/" .. className .. "." .. className .. "_C")
end

local function TryHookClass(converter)
    local okClass, classObj = pcall(function() return converter:GetClass() end)
    if not okClass or classObj == nil then return end
    local okName, classFullName = pcall(function() return classObj:GetFullName() end)
    if not okName or classFullName == nil then return end

    local assetPath = classFullName:gsub("^%a+ ", "")
    RegisterHooksForAssetPath(assetPath)
end

local function GetItemLabel(converter)
    local convKey = converter:GetFullName()
    local amount = converter.AmountInside
    if amount == nil or amount <= 0 then
        return nil
    end

    -- The specific input tag, if we know it - from the placement hook, or
    -- falling back to the broad category (always readable) otherwise.
    local inputTag = PlacedItemCache[convKey]
    local usingFallbackCategory = false
    if inputTag == nil then
        local ok, whatCanBePlaced = pcall(function() return converter.WhatCanBePlaced end)
        if ok and whatCanBePlaced ~= nil then
            inputTag = DisplayNames.FNameToString(whatCanBePlaced)
            usingFallbackCategory = true
        end
    end

    if inputTag == nil or inputTag == "" then
        return string.format("Unknown x%d", amount)
    end

    local itemName = DisplayNames.DisplayName(inputTag)
    local recipe = (not usingFallbackCategory) and GetRecipeInfo(converter, inputTag) or nil

    if recipe ~= nil and recipe.changesTo ~= nil then
        local outputName = DisplayNames.DisplayName(recipe.changesTo)
        local maxIn = recipe.maxIn
        if maxIn ~= nil and maxIn > 0 then
            return string.format("%s %d/%d. Will make %s. Placed in storage the next day.",
                itemName, amount, maxIn, outputName)
        end
        return string.format("%s x%d. Will make %s. Placed in storage the next day.", itemName, amount, outputName)
    end

    return string.format("%s x%d", itemName, amount)
end

-- The pointer to each station's Helper widget isn't named consistently across
-- Blueprints (Furnace uses "Helper", Crystal_Infusion uses "Help"/"Help2",
-- Yarn uses "Helper1", Crusher uses "ScaleHelper", etc), and some converters
-- (Crystal, Crystal_Infusion) drive two separate helper widgets at once. So we
-- just try every known variable name and process whichever ones resolve.
local HelperPropertyNames = { "Helper", "Helper1", "Helper2", "Help", "Help2", "ScaleHelper" }

local function UpdateOneHelper(converter, propName, helper, convKey)
    if helper == nil or not helper:IsValid() then
        return
    end

    local textBlock = helper.T_ItemName_3
    if textBlock == nil or not textBlock:IsValid() then
        return
    end

    local key = helper:GetFullName()
    if OriginalText[key] == nil then
        local ok, currentText = pcall(function()
            return KismetTextLibrary:Conv_TextToString(textBlock:GetText())
        end)
        if ok then
            local ok2, textStr = pcall(function() return currentText:ToString() end)
            OriginalText[key] = ok2 and textStr or tostring(currentText)
        else
            OriginalText[key] = ""
        end
    end

    local base = OriginalText[key]
    local itemLabel = GetItemLabel(converter)
    -- Once something's placed, our sentence already covers everything the
    -- original directions said, so replace it entirely instead of appending.
    -- When empty, keep the original "Place X Inside..." instructions.
    local newText = itemLabel ~= nil and itemLabel or base

    pcall(function()
        local ftext = KismetTextLibrary:Conv_StringToText(newText)
        textBlock:SetText(ftext)
    end)
end

local function UpdateConverter(converter)
    local convKey = converter:GetFullName()

    -- BuzzBrew's popup only ever renders once no matter what we write to it,
    -- and every fix attempted made it worse (stuck permanently visible,
    -- blank on the very first hover, etc) - so it's left completely alone
    -- here, untouched, to behave exactly like vanilla.
    if convKey:find("BuzzBrew", 1, true) ~= nil then
        return
    end

    for _, propName in ipairs(HelperPropertyNames) do
        local ok, helper = pcall(function() return converter[propName] end)
        if ok and helper ~= nil then
            pcall(UpdateOneHelper, converter, propName, helper, convKey)
        end
    end
end

LoopAsync(20, function()
    -- Top-level safety net: if ANYTHING below throws uncaught, UE4SS stops
    -- rescheduling this loop entirely - a single bad/stale object reference
    -- (e.g. an actor mid-destruction during a map/day transition) would
    -- silently kill the mod for good until the next reload. Every call was
    -- already pcall-wrapped individually except converter:IsValid() itself -
    -- wrapping the whole tick is a second layer of defense against that
    -- ever happening again from something we haven't hit yet.
    pcall(function()
        pcall(DisplayNames.ScanStorageWidgets)

        local ok, converters = pcall(FindAllOf, "BP_Converter_Base_C")
        if ok and converters ~= nil then
            for _, converter in pairs(converters) do
                local okValid, isValid = pcall(function() return converter:IsValid() end)
                if okValid and isValid then
                    pcall(TryHookClass, converter)
                    pcall(BuildRecipeCache, converter)
                    pcall(UpdateConverter, converter)
                end
            end
        end
    end)
    return false
end)
