-- NR_Patch_Livestock.lua
-- Monkey-patches vanilla ISDesignationZonePanel and animal-related menus
-- to open NR_LivestockZonePanel and related NR panels.

require "NeatRocco/NR_Livestock/NR_LivestockZonePanel"
require "NeatRocco/NR_Livestock/NR_CheckZonePanel"
require "NeatRocco/NR_Livestock/NR_TrailerPanel"
require "NeatRocco/NR_Livestock/NR_FeedingTroughPanel"

-- Cache vanilla functions before patching
ISDesignationZonePanel._NR_old_toggleZoneUI                    = ISDesignationZonePanel._NR_old_toggleZoneUI                    or ISDesignationZonePanel.toggleZoneUI
ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork = ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork or ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork
AnimalContextMenu._NR_old_onCheckZone                          = AnimalContextMenu._NR_old_onCheckZone                          or AnimalContextMenu.onCheckZone
ISCheckAnimalInsideTrailer._NR_old_perform                     = ISCheckAnimalInsideTrailer._NR_old_perform                     or ISCheckAnimalInsideTrailer.perform
ISFeedingTroughMenu._NR_old_onTroughInfo                       = ISFeedingTroughMenu._NR_old_onTroughInfo                       or ISFeedingTroughMenu.onInfo

-- overrides
local function NR_toggleZoneUI(playerNum)
    local player = getSpecificPlayer(playerNum)
    if NR_LivestockZonePanel.instance then
        local inst = NR_LivestockZonePanel.instance
        if inst:getIsVisible() then
            inst:close()
        else
            inst:setVisible(true)
            inst:addToUIManager()
            inst:populateList()
            inst:centerOnScreen(playerNum)
            if getJoypadData(playerNum) then
                setJoypadFocus(playerNum, inst)
            end
        end
    else
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local w  = math.max(NR_Config.minActionBarWidth, math.floor(sw * 0.3))
        local x  = math.floor(sw / 2 - w / 2)
        local y  = math.floor(sh / 2 - NR_Config.minWindowHeight / 2)

        local panel = NR_LivestockZonePanel:new(x, y, w, NR_Config.minWindowHeight, player)
        panel:initialise()
        panel:addToUIManager()
        if getJoypadData(playerNum) then
            setJoypadFocus(playerNum, panel)
        end
    end
end

local function NR_OnDesignationZoneUpdatedNetwork()
    if NR_LivestockZonePanel.instance and NR_LivestockZonePanel.instance:getIsVisible() then
        NR_LivestockZonePanel.instance:populateList()
    end
end

local function NR_onCheckZone(zone, playerObj)
    local playerNum = playerObj:getPlayerNum()
    local ui = NR_CheckZonePanel:new(
        getPlayerScreenLeft(playerNum) + 50,
        getPlayerScreenTop(playerNum) + 50,
        600, 600, playerObj, zone
    )
    ui:initialise()
    ui:addToUIManager()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
    ISAnimalZoneFirstInfo.showUI(playerNum, false)
end

local function NR_onTroughInfo(trough, chr)
    local playerNum = chr:getPlayerNum()
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local panel = NR_FeedingTroughPanel:new(
        math.floor(sw / 2 - 200),
        math.floor(sh / 2 - 100),
        trough, chr
    )
    panel:initialise()
    panel:addToUIManager()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, panel)
    end
end

local function NR_trailerPerform(self)
    ISBaseTimedAction.perform(self)
    local ui = NR_TrailerPanel:new(self.vehicle, self.character)
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    local playerNum = self.character:getPlayerNum()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
end

-- Livestock panels (zone panel, check zone, trailer, feeding trough) - controlled by per-window toggle
local function NR_applyLivestockToggle(enabled)
    if enabled then
        ISDesignationZonePanel.toggleZoneUI                    = NR_toggleZoneUI
        ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork = NR_OnDesignationZoneUpdatedNetwork
        AnimalContextMenu.onCheckZone                          = NR_onCheckZone
        ISCheckAnimalInsideTrailer.perform                     = NR_trailerPerform
        ISFeedingTroughMenu.onInfo                             = NR_onTroughInfo
    else
        ISDesignationZonePanel.toggleZoneUI                    = ISDesignationZonePanel._NR_old_toggleZoneUI
        ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork = ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork
        AnimalContextMenu.onCheckZone                          = AnimalContextMenu._NR_old_onCheckZone
        ISCheckAnimalInsideTrailer.perform                     = ISCheckAnimalInsideTrailer._NR_old_perform
        ISFeedingTroughMenu.onInfo                             = ISFeedingTroughMenu._NR_old_onTroughInfo
        if NR_LivestockZonePanel.instance and NR_LivestockZonePanel.instance:getIsVisible() then
            NR_LivestockZonePanel.instance:close()
        end
    end
end

NR_RegisterWindowToggleCallback("Livestock", NR_applyLivestockToggle)
