-- NR_Patch.lua
-- Monkey-patches vanilla functions to open NF windows instead of vanilla windows.
-- Respects the ModOptions toggle: when disabled, vanilla functions are restored.
require "NeatRocco/NR_ModOptions"
require "NeatRocco/NR_Generic/NR_ColorPicker"
require "NeatRocco/NR_Generic/NR_TextBox"
require "NeatRocco/NR_Generic/NR_ModalRichText"
require "NeatRocco/NR_Generic/NR_ConfirmDialog"
require "NeatRocco/NR_Generic/NR_BombTimerDialog"
require "NeatRocco/NR_Generic/NR_AlarmClockDialog"
require "NeatRocco/NR_Generic/NR_DigitalCode"
require "NeatRocco/NR_Fitness/NR_FitnessPanel"

-- #################
-- ### LIVESTOCK ###
-- #################
require "NeatRocco/NR_Livestock/NR_CheckZonePanel"
require "NeatRocco/NR_Livestock/NR_AnimalUI"
require "NeatRocco/NR_Livestock/NR_TrailerPanel"
require "NeatRocco/NR_Livestock/NR_FeedingTroughPanel"
-- Cache vanilla functions before patching
ISDesignationZonePanel._NR_old_toggleZoneUI                    = ISDesignationZonePanel._NR_old_toggleZoneUI                    or ISDesignationZonePanel.toggleZoneUI
ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork = ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork or ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork
AnimalContextMenu._NR_old_onCheckZone                          = AnimalContextMenu._NR_old_onCheckZone                          or AnimalContextMenu.onCheckZone
AnimalContextMenu._NR_old_onAnimalInfo                         = AnimalContextMenu._NR_old_onAnimalInfo                         or AnimalContextMenu.onAnimalInfo
ISOpenAnimalInfo._NR_old_perform                               = ISOpenAnimalInfo._NR_old_perform                               or ISOpenAnimalInfo.perform
ISCheckAnimalInsideTrailer._NR_old_perform                     = ISCheckAnimalInsideTrailer._NR_old_perform                     or ISCheckAnimalInsideTrailer.perform
ISFeedingTroughMenu._NR_old_onTroughInfo                       = ISFeedingTroughMenu._NR_old_onInfo
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
local function NR_onAnimalInfo(animal, chr)
    local playerNum = chr:getPlayerNum()
    local ui = NR_AnimalUI:new(getPlayerScreenLeft(playerNum)+100, getPlayerScreenTop(playerNum)+100, animal, chr)
    ui:initialise()
    ui:addToUIManager()
    if getJoypadData(playerNum) then
        ui.prevFocus = getJoypadFocus(playerNum)
        setJoypadFocus(playerNum, ui)
    end
end
local function NR_animalInfoPerform(self)
    local ui = NR_AnimalUI:new(
        getPlayerScreenLeft(self.playerNum) + 100,
        getPlayerScreenTop(self.playerNum) + 100,
        self.animal, self.player
    )
    ui:initialise()
    ui:addToUIManager()
    ui.prevFocus = self.prevFocus
    if getJoypadData(self.playerNum) then
        if self.prevFocus ~= nil and (self.prevFocus.Type == "ISVehicleAnimalUI" or self.prevFocus.Type == "NR_TrailerPanel") then
            self.prevFocus:setVisible(false)
        end
        setJoypadFocus(self.playerNum, ui)
    end
    ISBaseTimedAction.perform(self)
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
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyLivestockToggle(enabled)
    if enabled then
        ISDesignationZonePanel.toggleZoneUI                    = NR_toggleZoneUI
        ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork = NR_OnDesignationZoneUpdatedNetwork
        AnimalContextMenu.onCheckZone                          = NR_onCheckZone
        AnimalContextMenu.onAnimalInfo                         = NR_onAnimalInfo
        ISOpenAnimalInfo.perform                               = NR_animalInfoPerform
        ISCheckAnimalInsideTrailer.perform                     = NR_trailerPerform
        ISFeedingTroughMenu.onInfo                             = NR_onTroughInfo
    else
        -- Restore vanilla
        ISDesignationZonePanel.toggleZoneUI                    = ISDesignationZonePanel._NR_old_toggleZoneUI
        ISDesignationZonePanel.OnDesignationZoneUpdatedNetwork = ISDesignationZonePanel._NR_old_OnDesignationZoneUpdatedNetwork
        AnimalContextMenu.onCheckZone                          = AnimalContextMenu._NR_old_onCheckZone
        AnimalContextMenu.onAnimalInfo                         = AnimalContextMenu._NR_old_onAnimalInfo
        ISOpenAnimalInfo.perform                               = ISOpenAnimalInfo._NR_old_perform
        ISCheckAnimalInsideTrailer.perform                     = ISCheckAnimalInsideTrailer._NR_old_perform
        ISFeedingTroughMenu.onInfo                             = ISFeedingTroughMenu._NR_old_onTroughInfo
        -- Hide panels if open
        if NR_LivestockZonePanel.instance and NR_LivestockZonePanel.instance:getIsVisible() then
            NR_LivestockZonePanel.instance:close()
        end
    end
end

-- #############
-- ### HUTCH ###
-- #############
require "NeatRocco/NR_Hutch/NR_HutchPanel"
-- Cache vanilla ShowWindow before patching
ISHutchUI._NR_old_ShowWindow = ISHutchUI._NR_old_ShowWindow or ISHutchUI.ShowWindow
-- overrides
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
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyHutchToggle(enabled)
    if enabled then
        ISHutchUI.ShowWindow = NR_ShowWindow
    else
        ISHutchUI.ShowWindow = ISHutchUI._NR_old_ShowWindow
        -- Close any open NR_HutchPanel instances
        for i = 0, 3 do
            local inst = NR_HutchPanel.ui[i]
            if inst then inst:close() end
        end
    end
end

-- ###################
-- ### ButcherHook ###
-- ###################
require "NeatRocco/NR_ButcherHook/NR_ButcherHookPanel"
-- Cache vanilla perform before patching
ISOpenButcherHookUI._NR_old_perform = ISOpenButcherHookUI._NR_old_perform or ISOpenButcherHookUI.perform
-- overrides
local function NR_performButcherHook(self)
    -- Must be called first, like vanilla (removes action from queue)
    ISBaseTimedAction.perform(self)

    -- Close any existing panel for the same hook (splitscreen / multiplayer)
    for playerNum = 1, 4 do
        local existing = NR_ButcherHookPanel.ui and NR_ButcherHookPanel.ui[playerNum - 1] or nil
        if existing ~= nil and existing.hook == self.hook then
            existing:close()
        end
    end

    local ui = NR_ButcherHookPanel:new(
        getPlayerScreenLeft(self.playerNum) + 100,
        getPlayerScreenTop(self.playerNum) + 100,
        self.hook, self.player
    )
    ui:initialise()
    ui:addToUIManager()
    if getJoypadData(self.playerNum) then
        setJoypadFocus(self.playerNum, ui)
    end
end
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyButcherHookToggle(enabled)
    if enabled then
        ISOpenButcherHookUI.perform = NR_performButcherHook
    else
        ISOpenButcherHookUI.perform = ISOpenButcherHookUI._NR_old_perform
        -- Close any open BH panel
        for i = 0, 3 do
            local inst = NR_ButcherHookPanel.ui[i]
            if inst then inst:close() end
        end
    end
end

-- #################
-- ### Generator ###
-- #################
require "NeatRocco/NR_Generator/NR_GeneratorPanel"
-- Cache vanilla perform before patching
ISGeneratorInfoAction._NR_old_perform = ISGeneratorInfoAction._NR_old_perform or ISGeneratorInfoAction.perform
-- overrides
local function NR_performGenerator(self)
    local existing = NR_GeneratorPanel.panels[self.character]

    -- Si le panneau existant concerne un autre objet, le fermer d'abord
    if existing and existing.object ~= self.object then
        existing:close()
        existing = nil
    end

    if existing then
        existing:setObject(self.object)
        existing:setVisible(true)
        existing:addToUIManager()
    else
        local ui = NR_GeneratorPanel:new(
            getPlayerScreenLeft(self.playerNum) + 70,
            getPlayerScreenTop(self.playerNum) + 50,
            self.character, self.object
        )
        ui:initialise()
        ui:addToUIManager()
    end

    local jd = JoypadState.players[self.playerNum + 1]
    if jd then jd.focus = NR_GeneratorPanel.panels[self.character] end

    -- Obligatoire : retire l'action de la queue (comme vanilla)
    ISBaseTimedAction.perform(self)
end
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyGeneratorToggle(enabled)
    if enabled then
        ISGeneratorInfoAction.perform = NR_performGenerator
    else
        ISGeneratorInfoAction.perform = ISGeneratorInfoAction._NR_old_perform
        -- Fermer tous les panneaux NG ouverts
        for _, panel in pairs(NR_GeneratorPanel.panels) do
            if panel then panel:close() end
        end
    end
end

-- ###########
-- ### BBQ ###
-- ###########
require "NeatRocco/NR_BBQ/NR_BBQPanel"
-- Cache vanilla perform before patching
ISBBQInfoAction._NR_old_perform          = ISBBQInfoAction._NR_old_perform          or ISBBQInfoAction.perform
ISBBQRemovePropaneTank._NR_old_perform   = ISBBQRemovePropaneTank._NR_old_perform   or ISBBQRemovePropaneTank.perform
-- overrides
local function NR_performBBQ(self)
    local existing = NR_BBQPanel.panels[self.character]

    if existing and existing.object ~= self.bbq then
        existing:close()
        existing = nil
    end

    if existing then
        existing:setObject(self.bbq)
        existing:setVisible(true)
        existing:addToUIManager()
    else
        local ui = NR_BBQPanel:new(
            getPlayerScreenLeft(self.playerNum) + 70,
            getPlayerScreenTop(self.playerNum) + 50,
            self.character, self.bbq
        )
        ui:initialise()
        ui:addToUIManager()
    end

    local jd = JoypadState.players[self.playerNum + 1]
    if jd then jd.focus = NR_BBQPanel.panels[self.character] end

    ISBaseTimedAction.perform(self)
end

local function NR_performBBQRemoveTank(self)
    ISBBQRemovePropaneTank._NR_old_perform(self)
    local panel = NR_BBQPanel.panels[self.character]
    if panel then panel.width = 1 end
end

-- Toggle callback: swap between NR override and vanilla
local function NR_applyBBQToggle(enabled)
    if enabled then
        ISBBQInfoAction.perform        = NR_performBBQ
        ISBBQRemovePropaneTank.perform = NR_performBBQRemoveTank
    else
        ISBBQInfoAction.perform        = ISBBQInfoAction._NR_old_perform
        ISBBQRemovePropaneTank.perform = ISBBQRemovePropaneTank._NR_old_perform
        for _, panel in pairs(NR_BBQPanel.panels) do
            if panel then panel:close() end
        end
    end
end

-- ############
-- ### Bake ###
-- ############
require "NeatRocco/NR_Bake/NR_OvenPanel"
require "NeatRocco/NR_Bake/NR_MicrowavePanel"

-- Cache vanilla perform before patching
ISOvenUITimedAction._NR_old_perform = ISOvenUITimedAction._NR_old_perform or ISOvenUITimedAction.perform
-- overrides
local function NR_performBake(self)
    -- Must be called first, like vanilla (removes action from queue)
    ISBaseTimedAction.perform(self)

    local player = self.character:getPlayerNum()

    if self.mcwave then
        -- Microwave: use NR_MicrowavePanel
        if NR_MicrowavePanel.instance and NR_MicrowavePanel.instance[player + 1] then
            NR_MicrowavePanel.instance[player + 1]:close()
        end
        local _pad  = NR_Config.padding
        local _tex1 = getTexture("media/ui/Knobs/KnobBGMicrowaveTemp.png")
        local _tex2 = getTexture("media/ui/Knobs/KnobBGMicrowaveTimer.png")
        local _w    = _pad + _tex1:getWidthOrig() + _pad + _tex2:getWidthOrig() + _pad
        local ui = NR_MicrowavePanel:new(0, 0, _w, 300, self.mcwave, self.character)
        ui:initialise()
        ui:addToUIManager()
        if JoypadState.players[player + 1] then
            ui.prevFocus = JoypadState.players[player + 1].focus
            setJoypadFocus(player, ui)
        end
        return
    end

    -- Oven: use NR_OvenPanel
    if NR_OvenPanel.instance and NR_OvenPanel.instance[player + 1] then
        NR_OvenPanel.instance[player + 1]:close()
    end

    local _pad  = NR_Config.padding
    local _tex1 = getTexture("media/ui/Knobs/KnobBGFarhenOvenTemp.png")
    local _tex2 = getTexture("media/ui/Knobs/KnobBGOvenTimer.png")
    local _w    = _pad + _tex1:getWidthOrig() + _pad + _tex2:getWidthOrig() + _pad
    local ui = NR_OvenPanel:new(0, 0, _w, 400, self.stove, self.character)
    ui:initialise()
    ui:addToUIManager()
    if JoypadState.players[player + 1] then
        ui.prevFocus = JoypadState.players[player + 1].focus
        setJoypadFocus(player, ui)
    end
end
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyBakeToggle(enabled)
    if enabled then
        ISOvenUITimedAction.perform = NR_performBake
    else
        ISOvenUITimedAction.perform = ISOvenUITimedAction._NR_old_perform
        -- Close any open NBk panels
        for i = 1, 4 do
            local inst = NR_OvenPanel.instance[i]
            if inst then inst:close() end
            inst = NR_MicrowavePanel.instance[i]
            if inst then inst:close() end
        end
    end
end




-- ###############
-- ### Farming ###
-- ###############
require "NeatRocco/NR_Farming/NR_PlantPanel"
-- Cache vanilla perform before patching
ISPlantInfoAction._NR_old_perform = ISPlantInfoAction._NR_old_perform or ISPlantInfoAction.perform
-- override
local function NR_performPlantInfo(self)
    local existing = NR_PlantPanel.panels[self.character]

    if existing then
        existing:setPlant(self.plant)
        existing:setVisible(true)
        existing:addToUIManager()
    else
        local ui = NR_PlantPanel:new(
            getPlayerScreenLeft(self.playerNum) + 70,
            getPlayerScreenTop(self.playerNum) + 50,
            self.character, self.plant
        )
        ui:initialise()
        ui:addToUIManager()
    end

    local jd = JoypadState.players[self.playerNum + 1]
    if jd then jd.focus = NR_PlantPanel.panels[self.character] end

    ISBaseTimedAction.perform(self)
end
-- Toggle callback: swap between NR override and vanilla
local function NR_applyFarmingToggle(enabled)
    if enabled then
        ISPlantInfoAction.perform = NR_performPlantInfo
    else
        ISPlantInfoAction.perform = ISPlantInfoAction._NR_old_perform
        -- Close any open NR_PlantPanel instances
        for _, panel in pairs(NR_PlantPanel.panels) do
            if panel then panel:close() end
        end
    end
end

-- ###############
-- ### Garment ###
-- ###############
require "NeatRocco/NR_Garment/NR_GarmentPanel"
-- Cache vanilla function before patching
ISInventoryPaneContextMenu._NR_old_onInspectClothingUI = ISInventoryPaneContextMenu._NR_old_onInspectClothingUI or ISInventoryPaneContextMenu.onInspectClothingUI
-- override
local function NR_onInspectClothingUI(player, clothing)
    local playerNum = player:getPlayerNum()
    -- Close previous garment window for this player if any
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
-- Toggle callback: swap between NR override and vanilla
local function NR_applyGarmentToggle(enabled)
    if enabled then
        ISInventoryPaneContextMenu.onInspectClothingUI = NR_onInspectClothingUI
    else
        ISInventoryPaneContextMenu.onInspectClothingUI = ISInventoryPaneContextMenu._NR_old_onInspectClothingUI
        -- Close any open garment panels
        for pn = 0, 3 do
            local inst = ISGarmentUI.windows[pn]
            if inst and inst.Type == "NR_GarmentPanel" then inst:close() end
        end
    end
end

-- ###############
-- ### Search  ###
-- ###############
require "NeatRocco/NR_Search/NR_SearchPanel"
-- Cache vanilla functions before patching
ISSearchWindow._NR_old_toggleWindow = ISSearchWindow._NR_old_toggleWindow or ISSearchWindow.toggleWindow
ISSearchWindow._NR_old_showWindow   = ISSearchWindow._NR_old_showWindow   or ISSearchWindow.showWindow
ISSearchWindow._NR_old_createUI     = ISSearchWindow._NR_old_createUI     or ISSearchWindow.createUI
ISSearchWindow._NR_old_destroyUI    = ISSearchWindow._NR_old_destroyUI    or ISSearchWindow.destroyUI
-- overrides
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
-- Toggle callback: swap between NR overrides and vanilla
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
        -- Close open panels
        for _, panel in pairs(NR_SearchPanel.players) do
            if panel then panel:close() end
        end
    end
end

-- ######################
-- ### VehicleMechanics ###
-- ######################
require "NeatRocco/NR_Mech/NR_VehicleMechanicsPanel"
-- Cache vanilla functions before patching
ISOpenMechanicsUIAction._NR_old_perform         = ISOpenMechanicsUIAction._NR_old_perform         or ISOpenMechanicsUIAction.perform
ISVehicleMechanics._NR_old_OnMechanicActionDone = ISVehicleMechanics._NR_old_OnMechanicActionDone or ISVehicleMechanics.OnMechanicActionDone
-- overrides
local function NR_performMechanicsUI(self)
    local playerNum = self.character:getPlayerNum()
    local ui = NR_VehicleMechanicsPanel.panels[playerNum]
    if not ui then
        ui = NR_VehicleMechanicsPanel:new(0, 0, self.character, nil)
        ui:initialise()
        ui:instantiate()  -- createChildren() is called here, which creates listbox/bodyworklist
        NR_VehicleMechanicsPanel.panels[playerNum] = ui
    end
    ui.vehicle  = self.vehicle
    ui.usedHood = self.usedHood
    ui:initParts()
    ui:setVisible(true, JoypadState.players[playerNum + 1])
    ui:addToUIManager()
    ui:calculateLayout(ui.width, ui.height)
    ISBaseTimedAction.perform(self)
end
local function NR_onMechanicActionDone(chr, success)
    local nrUI = NR_VehicleMechanicsPanel.panels[chr:getPlayerNum()]
    if nrUI and nrUI:isReallyVisible() then
        if success then nrUI:startFlashGreen() else nrUI:startFlashRed() end
    else
        ISVehicleMechanics._NR_old_OnMechanicActionDone(chr, success)
    end
end
-- Toggle callback: swap between NR overrides and vanilla
local function NR_applyMechToggle(enabled)
    if enabled then
        ISOpenMechanicsUIAction.perform = NR_performMechanicsUI
        Events.OnMechanicActionDone.Remove(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        Events.OnMechanicActionDone.Add(NR_onMechanicActionDone)
    else
        ISOpenMechanicsUIAction.perform = ISOpenMechanicsUIAction._NR_old_perform
        Events.OnMechanicActionDone.Remove(NR_onMechanicActionDone)
        Events.OnMechanicActionDone.Add(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        -- Close any open NR panels
        for i = 0, 3 do
            local ui = NR_VehicleMechanicsPanel.panels[i]
            if ui then ui:close() end
        end
    end
end

-- #####################
-- ### AnimalTracks   ###
-- #####################
require "NeatRocco/NR_AnimalTracks/NR_AnimalTracksPanel"
-- Cache vanilla perform before patching
ISInspectAnimalTrackAction._NR_old_perform = ISInspectAnimalTrackAction._NR_old_perform or ISInspectAnimalTrackAction.perform
-- override
local function NR_performAnimalTracks(self)
    ISBaseTimedAction.perform(self)

    local existing = NR_AnimalTracksPanel.panels[self.character]
    if existing then existing:close() end

    local playerNum = self.character:getPlayerNum()
    local ui = NR_AnimalTracksPanel:new(
        getPlayerScreenLeft(playerNum) + 100,
        getPlayerScreenTop(playerNum) + 100,
        self.track, self.character
    )
    ui:initialise()
    ui:addToUIManager()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
end
-- Toggle callback
local function NR_applyAnimalTracksToggle(enabled)
    if enabled then
        ISInspectAnimalTrackAction.perform = NR_performAnimalTracks
    else
        ISInspectAnimalTrackAction.perform = ISInspectAnimalTrackAction._NR_old_perform
        for _, panel in pairs(NR_AnimalTracksPanel.panels) do
            if panel then panel:close() end
        end
    end
end

-- ######################
-- ### FluidContainer ###
-- ######################
require "NeatRocco/NR_Fluid/NR_FluidContainerPanel"
ISFluidInfoUI._NR_old_OpenPanel = ISFluidInfoUI._NR_old_OpenPanel or ISFluidInfoUI.OpenPanel
local function NR_applyFluidContainerToggle(enabled)
    if enabled then
        ISFluidInfoUI.OpenPanel = NR_FluidContainerPanel.OpenPanel
    else
        ISFluidInfoUI.OpenPanel = ISFluidInfoUI._NR_old_OpenPanel
        for pn = 0, 3 do
            local inst = NR_FluidContainerPanel.players[pn]
            if inst then inst:close() end
        end
    end
end

-- ####################
-- ### FluidTransfer ###
-- ####################
require "NeatRocco/NR_Fluid/NR_FluidTransferPanel"
ISFluidTransferUI._NR_old_OpenPanel = ISFluidTransferUI._NR_old_OpenPanel or ISFluidTransferUI.OpenPanel
local function NR_applyFluidTransferToggle(enabled)
    if enabled then
        ISFluidTransferUI.OpenPanel = NR_FluidTransferPanel.OpenPanel
    else
        ISFluidTransferUI.OpenPanel = ISFluidTransferUI._NR_old_OpenPanel
        for pn = 0, 3 do
            local entry = NR_FluidTransferPanel.players[pn]
            if entry and entry.instance then entry.instance:close() end
        end
    end
end

-- #################
-- ### Literature ###
-- #################
require "NeatRocco/NR_Literature/NR_LiteraturePanel"
require "NeatRocco/NR_CharInfo/NR_CharInfoPanel"
-- Cache vanilla function before patching
ISCharacterScreen._NR_old_onShowLiterature = ISCharacterScreen._NR_old_onShowLiterature or ISCharacterScreen.onShowLiterature
-- override
local function NR_onShowLiterature(self)
    if self.literatureUI == nil or self.literatureUI.Type ~= "NR_LiteraturePanel" then
        local x = getPlayerScreenLeft(self.playerNum) + 100
        local y = getPlayerScreenTop(self.playerNum) + 50
        local w = 475
        local h = getPlayerScreenHeight(self.playerNum) - 100
        self.literatureUI = NR_LiteraturePanel:new(x, y, w, h, self.char, self)
        self.literatureUI:initialise()
    end
    self.literatureUI:addToUIManager()
    if self.joyfocus then
        getPlayerInfoPanel(self.playerNum).drawJoypadFocus = false
        setJoypadFocus(self.playerNum, self.literatureUI)
    end
end
-- Toggle callback
local function NR_applyLiteratureToggle(enabled)
    if enabled then
        ISCharacterScreen.onShowLiterature = NR_onShowLiterature
    else
        ISCharacterScreen.onShowLiterature = ISCharacterScreen._NR_old_onShowLiterature
        for pn = 0, 3 do
            local infoPanel = getPlayerInfoPanel(pn)
            if infoPanel and infoPanel.charScreen and infoPanel.charScreen.literatureUI then
                local ui = infoPanel.charScreen.literatureUI
                if ui.Type == "NR_LiteraturePanel" then
                    ui:close()
                    infoPanel.charScreen.literatureUI = nil
                end
            end
        end
    end
end

-- ######################
-- ### CharInfo Window ###
-- ######################
-- Approach: patch ISCharacterInfoWindow.new AND rebuild pdata.characterInfo + infopanel
-- references at toggle time (same pattern as CleanUI InventoryUIModeSwitcher).
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

    -- Close old window
    pcall(function() old:setVisible(false) end)
    pcall(function() old:removeFromUIManager() end)

    -- Recreate with whichever class is now active (NR or vanilla, new() is already set)
    local newWin = ISCharacterInfoWindow:new(x, y, w, h, pn)
    newWin:initialise()
    newWin:addToUIManager()
    newWin:setVisible(false)

    -- Update all cached references (mirrors CleanUI pattern)
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
    -- Rebuild existing windows for all active players (no-op if game not yet started)
    for pn = 0, 3 do
        pcall(function() NR_rebuildCharInfoForPlayer(pn) end)
    end
end

-- ############################
-- ### AnimalZoneFirstInfo  ###
-- ############################
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

-- ######################################
-- ### Generic class replacement patch ###
-- ######################################
-- Redirects VanillaClass:new(...) to ReplacementClass:new(...).
-- Subclasses that call VanillaClass.new(self, ...) pass through unchanged.
local function NR_MakePatch(VanillaClass, ReplacementClass)
    VanillaClass._NR_old_new = VanillaClass._NR_old_new or VanillaClass.new
    local function patched(self, ...)
        if self == VanillaClass then
            return VanillaClass._NR_old_new(ReplacementClass, ...)
        end
        return VanillaClass._NR_old_new(self, ...)
    end
    NR_RegisterToggleCallback(function(enabled)
        VanillaClass.new = enabled and patched or VanillaClass._NR_old_new
    end)
end

NR_MakePatch(ISColorPicker,      NR_ColorPicker)
NR_MakePatch(ISTextBox,          NR_TextBox)
NR_MakePatch(ISModalRichText,    NR_ModalRichText)
NR_MakePatch(ISModalDialog,      NR_ConfirmDialog)
NR_MakePatch(ISBombTimerDialog,   NR_BombTimerDialog)
NR_MakePatch(ISAlarmClockDialog, NR_AlarmClockDialog)
NR_MakePatch(ISDigitalCode,      NR_DigitalCode)
NR_MakePatch(ISFitnessUI,        NR_FitnessPanel)

-- ##############################
-- ### RegisterToggleCallback ###
-- ##############################
NR_RegisterToggleCallback(NR_applyLivestockToggle)
NR_RegisterToggleCallback(NR_applyHutchToggle)
NR_RegisterToggleCallback(NR_applyButcherHookToggle)
NR_RegisterToggleCallback(NR_applyGeneratorToggle)
NR_RegisterToggleCallback(NR_applyBBQToggle)
NR_RegisterToggleCallback(NR_applyBakeToggle)
NR_RegisterToggleCallback(NR_applyFarmingToggle)
NR_RegisterToggleCallback(NR_applyGarmentToggle)
NR_RegisterToggleCallback(NR_applySearchToggle)
NR_RegisterToggleCallback(NR_applyMechToggle)
NR_RegisterToggleCallback(NR_applyAnimalTracksToggle)
NR_RegisterToggleCallback(NR_applyFluidContainerToggle)
NR_RegisterToggleCallback(NR_applyFluidTransferToggle)
NR_RegisterToggleCallback(NR_applyLiteratureToggle)
NR_RegisterToggleCallback(NR_applyCharInfoToggle)
NR_RegisterToggleCallback(NR_applyAnimalZoneFirstInfoToggle)