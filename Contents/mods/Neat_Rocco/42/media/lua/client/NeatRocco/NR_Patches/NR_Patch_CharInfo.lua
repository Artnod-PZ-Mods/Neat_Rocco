-- NR_Patch_CharInfo.lua
-- Patches ISCharacterInfoWindow.new AND rebuilds pdata.characterInfo + infopanel
-- references at toggle time (same pattern as CleanUI InventoryUIModeSwitcher).

require "NeatRocco/NR_CharInfo/NR_CharInfoPanel"

ISCharacterInfoWindow._NR_old_new = ISCharacterInfoWindow._NR_old_new or ISCharacterInfoWindow.new

local function NR_charInfoNew(cls, x, y, w, h, playerNum)
    if cls == ISCharacterInfoWindow then
        return NR_CharInfoPanel:new(x, y, w, h, playerNum)
    end
    return ISCharacterInfoWindow._NR_old_new(cls, x, y, w, h, playerNum)
end

local function NR_rebuildCharInfoForPlayer(pn)
    local pdata = getPlayerData(pn)
    if not pdata or not pdata.characterInfo then return end

    local old = pdata.characterInfo
    local x = old.x or 0
    local y = old.y or 0
    local w = old.width or 400
    local h = old.height or 400

    pcall(function() old:setVisible(false) end)
    pcall(function() old:removeFromUIManager() end)

    local newWin = ISCharacterInfoWindow:new(x, y, w, h, pn)
    newWin:initialise()
    newWin:addToUIManager()
    newWin:setVisible(false)

    pdata.characterInfo = newWin
    ISCharacterInfoWindow.instance = newWin
    if pdata.equipped then
        pdata.equipped.infopanel = newWin
    end
end

local function NR_applyCharInfoToggle(enabled)
    if enabled then
        ISCharacterInfoWindow.new = NR_charInfoNew
    else
        ISCharacterInfoWindow.new = ISCharacterInfoWindow._NR_old_new
    end
    for pn = 0, 3 do
        pcall(function() NR_rebuildCharInfoForPlayer(pn) end)
    end
end

NR_RegisterToggleCallback(NR_applyCharInfoToggle)
