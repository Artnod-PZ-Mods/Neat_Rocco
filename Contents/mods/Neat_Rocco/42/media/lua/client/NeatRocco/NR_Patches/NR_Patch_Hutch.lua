-- NR_Patch_Hutch.lua
-- Monkey-patches ISHutchUI.ShowWindow to open NR_HutchPanel instead.

require "NeatRocco/NR_Hutch/NR_HutchPanel"

ISHutchUI._NR_old_ShowWindow = ISHutchUI._NR_old_ShowWindow or ISHutchUI.ShowWindow

local function NR_ShowWindow(playerObj, hutch)
    local playerNum = playerObj:getPlayerNum()

    -- Reuse existing panel for the same player (vanilla behavior)
    local ui = NR_HutchPanel.ui[playerNum]
    if ui == nil then
        ui = NR_HutchPanel:new(
            getPlayerScreenLeft(playerNum) + 100,
            getPlayerScreenTop(playerNum) + 100,
            hutch, playerObj
        )
        ui:initialise()
    end
    ui:addToUIManager()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
    return ui
end

local function NR_applyHutchToggle(enabled)
    if enabled then
        ISHutchUI.ShowWindow = NR_ShowWindow
    else
        ISHutchUI.ShowWindow = ISHutchUI._NR_old_ShowWindow
        for i = 0, 3 do
            local inst = NR_HutchPanel.ui[i]
            if inst then inst:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyHutchToggle)
