-- NR_Patch_Search.lua
-- Monkey-patches ISSearchWindow to use NR_SearchPanel.

require "NeatRocco/NR_Search/NR_SearchPanel"

ISSearchWindow._NR_old_toggleWindow = ISSearchWindow._NR_old_toggleWindow or ISSearchWindow.toggleWindow
ISSearchWindow._NR_old_showWindow   = ISSearchWindow._NR_old_showWindow   or ISSearchWindow.showWindow
ISSearchWindow._NR_old_createUI     = ISSearchWindow._NR_old_createUI     or ISSearchWindow.createUI
ISSearchWindow._NR_old_destroyUI    = ISSearchWindow._NR_old_destroyUI    or ISSearchWindow.destroyUI

local function NR_createSearchUI(playerNum)
    local character = getSpecificPlayer(playerNum)
    if character and not NR_SearchPanel.players[character] then
        local panel = NR_SearchPanel:new(character)
        panel:initialise()
        panel:addToUIManager()
        panel:setVisible(false)
    end
end

local function NR_toggleSearchWindow(character)
    if not NR_SearchPanel.players[character] then NR_createSearchUI(character:getPlayerNum()) end
    local panel = NR_SearchPanel.players[character]
    if not panel then return end
    local isVisible = not panel:getIsVisible()
    panel:setVisible(isVisible)
    panel.tooltipForced = nil
    if isVisible then
        panel:addToUIManager()
        panel:bringToTop()
        if JoypadState.players[panel.playerNum + 1] then
            setJoypadFocus(panel.playerNum, panel)
        end
        panel:checkShowFirstTimeSearchTutorial()
    end
end

local function NR_showSearchWindow(character)
    if not NR_SearchPanel.players[character] then NR_createSearchUI(character:getPlayerNum()) end
    local panel = NR_SearchPanel.players[character]
    if not panel then return end
    panel:setVisible(true)
    panel:addToUIManager()
    panel:bringToTop()
    panel:checkShowFirstTimeSearchTutorial()
end

local function NR_destroySearchUI(character)
    local panel = NR_SearchPanel.players[character]
    if panel then
        panel:setVisible(false)
        panel:removeFromUIManager()
        NR_SearchPanel.players[character] = nil
        ISSearchWindow.players[character] = nil
    end
end

local function NR_applySearchToggle(enabled)
    if enabled then
        ISSearchWindow.toggleWindow = NR_toggleSearchWindow
        ISSearchWindow.showWindow   = NR_showSearchWindow
        Events.OnCreatePlayer.Remove(ISSearchWindow._NR_old_createUI)
        Events.OnCreatePlayer.Add(NR_createSearchUI)
        Events.OnPlayerDeath.Remove(ISSearchWindow._NR_old_destroyUI)
        Events.OnPlayerDeath.Add(NR_destroySearchUI)
    else
        ISSearchWindow.toggleWindow = ISSearchWindow._NR_old_toggleWindow
        ISSearchWindow.showWindow   = ISSearchWindow._NR_old_showWindow
        Events.OnCreatePlayer.Remove(NR_createSearchUI)
        Events.OnCreatePlayer.Add(ISSearchWindow._NR_old_createUI)
        Events.OnPlayerDeath.Remove(NR_destroySearchUI)
        Events.OnPlayerDeath.Add(ISSearchWindow._NR_old_destroyUI)
        for _, panel in pairs(NR_SearchPanel.players) do
            if panel then panel:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applySearchToggle)
