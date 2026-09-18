-- BuzzBrewTooltip (experimental)
-- BuzzBrew is the one station ConverterTooltips.lua explicitly skips: its
-- Helper popup only ever renders once per game session, no matter what
-- gets written to it, and every attempt to force it back into the render
-- tree from a timer-based poll (SetVisibility, AddToViewport, clearing
-- text while hidden) either failed or made things worse (stuck permanently
-- visible, since the poll kept re-triggering on every tick with no way to
-- tell "still hovering" from "not hovering anymore"). Kept in its own
-- module so none of this experimentation can affect the stable feature.
--
-- The fix this time: BP_Converter_BuzzBrew_C overrides
-- HighlightItem(UPrimitiveComponent*), a function no other converter class
-- overrides. Diagnostic logging confirmed it fires reliably on every single
-- hover, with zero degradation, across many repeat hover cycles - hover
-- detection itself never breaks. So instead of polling on a timer and
-- guessing whether we're currently hovering, we force the popup visible
-- and update its text ONLY inside this hook - it naturally only runs while
-- a hover is actually happening, so there's no "stuck on forever" risk the
-- polling approach had.

local UEHelpers = require("UEHelpers")
local KismetTextLibrary = UEHelpers.GetKismetTextLibrary()
local DisplayNames = require("DisplayNames")

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

    local tagStr = DisplayNames.FNameToString(tagVal)
    if tagStr ~= nil and tagStr ~= "" and tagStr ~= "None" then
        PlacedItemCache[key] = tagStr
    end
end

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

-- BuzzBrew has a SEPARATE set of fields for the fruit stage
-- (FruitAmountInside/AddedFruit) - once fruit is added on top of honey,
-- that's the more relevant/current state to show, so it's checked first.
local function GetFruitLabel(converter)
    local okFruitAmt, fruitAmount = pcall(function() return converter.FruitAmountInside end)
    if not okFruitAmt or fruitAmount == nil or fruitAmount <= 0 then
        return nil
    end

    local okFruitTag, fruitTag = pcall(function() return converter.AddedFruit end)
    local fruitTagStr = (okFruitTag and fruitTag ~= nil) and DisplayNames.FNameToString(fruitTag) or nil
    if fruitTagStr == nil or fruitTagStr == "" or fruitTagStr == "None" then
        return string.format("Unknown fruit x%d", fruitAmount)
    end

    return string.format("%s x%d", DisplayNames.DisplayName(fruitTagStr), fruitAmount)
end

local function GetItemLabel(converter)
    local fruitLabel = GetFruitLabel(converter)
    if fruitLabel ~= nil then
        return fruitLabel
    end

    local convKey = converter:GetFullName()
    local okAmt, amount = pcall(function() return converter.AmountInside end)
    if not okAmt or amount == nil or amount <= 0 then
        return nil
    end

    local inputTag = PlacedItemCache[convKey]
    if inputTag == nil then
        local ok, whatCanBePlaced = pcall(function() return converter.WhatCanBePlaced end)
        if ok and whatCanBePlaced ~= nil then
            inputTag = DisplayNames.FNameToString(whatCanBePlaced)
        end
    end

    if inputTag == nil or inputTag == "" or inputTag == "None" then
        return string.format("Unknown x%d", amount)
    end

    return string.format("%s x%d", DisplayNames.DisplayName(inputTag), amount)
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

-- This is the exact shape that was confirmed working the first time:
-- SetVisibility/AddToViewport called unconditionally on every single
-- HighlightItem call, no throttling, no IsRendered() check. Later attempts
-- to "improve" this (gating on IsRendered, then a time-based cooldown)
-- were reactions to problems that showed up only after OTHER changes
-- (the fruit-check logic) were added at the same time - reverted back to
-- this known-good shape to isolate that, before touching anything else.
local function OnHighlightItem(Context, _Component)
    local okSelf, converter = pcall(function() return Context:get() end)
    if not okSelf or converter == nil or not converter:IsValid() then return end

    local okLabel, itemLabel = pcall(GetItemLabel, converter)
    if not okLabel then itemLabel = nil end

    local okHelper, helper = pcall(function() return converter.Help end)
    if not okHelper or helper == nil or not helper:IsValid() then return end

    pcall(function() helper:SetVisibility(0) end) -- 0 = Visible
    pcall(function() helper:AddToViewport(9999) end)

    pcall(ForceShowAndUpdate, helper, "T_ItemName_3", itemLabel)
    pcall(ForceShowAndUpdate, helper, "T_ItemName", itemLabel)
end

pcall(function()
    RegisterHook(
        "/Game/Interactive/Shop/Production/BP_Converter_BuzzBrew.BP_Converter_BuzzBrew_C:HighlightItem",
        OnHighlightItem
    )
end)

print("[CraftingContents] BuzzBrewTooltip hover-triggered hook registered")
