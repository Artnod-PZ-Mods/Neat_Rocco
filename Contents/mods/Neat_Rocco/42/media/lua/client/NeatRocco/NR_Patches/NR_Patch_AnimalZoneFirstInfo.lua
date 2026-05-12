-- NR_Patch_AnimalZoneFirstInfo.lua
-- Routes the vanilla AnimalZone first-info popup through ISModalRichText
-- (which itself is NR_-patched via NR_MakePatch in the main orchestrator).

ISAnimalZoneFirstInfo._NR_old_showUI = ISAnimalZoneFirstInfo._NR_old_showUI or ISAnimalZoneFirstInfo.showUI

local function NR_showAnimalZoneFirstInfo(playerNum, force)
    if force or getCore():getOptionShowFirstAnimalZoneInfo() then
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local title = getText("IGUI_DesignationZone_Info"):match("<SIZE:medium>%s*(.-)%s*<LINE>") or ""
        local ui = ISModalRichText:new(sw/2 - 300, sh/2 - 200, 600, 400,
            getText("IGUI_Animal_ZoneFirstInfo"), false, nil,
            function()
                getCore():setOptionShowFirstAnimalZoneInfo(false)
                getCore():saveOptions()
            end, playerNum)
        ui.windowTitle = title
        ui:initialise()
        ui.alwaysOnTop = true
        ui.chatText:paginate()
        ui:setHeightToContents()
        ui:ignoreHeightChange()
        ui:setY(sh/2 - ui:getHeight()/2)
        ui:addToUIManager()
        local jd = getJoypadData(playerNum)
        if jd then
            ui.prevFocus = jd.focus
            setJoypadFocus(playerNum, ui)
        end
    end
end

local function NR_applyAnimalZoneFirstInfoToggle(enabled)
    ISAnimalZoneFirstInfo.showUI = enabled and NR_showAnimalZoneFirstInfo or ISAnimalZoneFirstInfo._NR_old_showUI
end

NR_RegisterToggleCallback(NR_applyAnimalZoneFirstInfoToggle)
