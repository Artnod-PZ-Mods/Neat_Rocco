-- NR_Patch_Garment.lua
-- Monkey-patches ISInventoryPaneContextMenu.onInspectClothingUI to open NR_GarmentPanel.

require "NeatRocco/NR_Garment/NR_GarmentPanel"

ISInventoryPaneContextMenu._NR_old_onInspectClothingUI = ISInventoryPaneContextMenu._NR_old_onInspectClothingUI or ISInventoryPaneContextMenu.onInspectClothingUI

local function NR_onInspectClothingUI(player, clothing)
    local playerNum = player:getPlayerNum()
    if ISGarmentUI.windows[playerNum] and ISGarmentUI.windows[playerNum] ~= nil then
        ISGarmentUI.windows[playerNum]:close()
    end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local ui = NR_GarmentPanel:new(
        math.floor(sw / 2 - 150),
        math.floor(sh * 0.2),
        player, clothing
    )
    ui:initialise()
    ui:addToUIManager()
    if JoypadState.players[playerNum + 1] then
        ui.prevFocus = JoypadState.players[playerNum + 1].focus
        setJoypadFocus(playerNum, ui)
    end
end

local function NR_applyGarmentToggle(enabled)
    if enabled then
        ISInventoryPaneContextMenu.onInspectClothingUI = NR_onInspectClothingUI
    else
        ISInventoryPaneContextMenu.onInspectClothingUI = ISInventoryPaneContextMenu._NR_old_onInspectClothingUI
        for pn = 0, 3 do
            local inst = ISGarmentUI.windows[pn]
            if inst and inst.Type == "NR_GarmentPanel" then inst:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyGarmentToggle)
