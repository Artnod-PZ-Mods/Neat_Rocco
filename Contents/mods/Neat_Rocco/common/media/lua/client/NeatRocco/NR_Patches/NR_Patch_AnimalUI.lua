-- NR_Patch_AnimalUI.lua
-- Monkey-patches the vanilla animal info menu and ISOpenAnimalInfo action
-- to open NR_AnimalUI. Controlled by the global toggle only.

require "NeatRocco/NR_Animal/NR_AnimalUI"

-- Cache vanilla functions before patching
AnimalContextMenu._NR_old_onAnimalInfo = AnimalContextMenu._NR_old_onAnimalInfo or AnimalContextMenu.onAnimalInfo
ISOpenAnimalInfo._NR_old_perform       = ISOpenAnimalInfo._NR_old_perform       or ISOpenAnimalInfo.perform

-- overrides
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

local function NR_applyAnimalUIToggle(enabled)
    if enabled then
        AnimalContextMenu.onAnimalInfo = NR_onAnimalInfo
        ISOpenAnimalInfo.perform       = NR_animalInfoPerform
    else
        AnimalContextMenu.onAnimalInfo = AnimalContextMenu._NR_old_onAnimalInfo
        ISOpenAnimalInfo.perform       = ISOpenAnimalInfo._NR_old_perform
    end
end

NR_RegisterWindowToggleCallback("AnimalUI", NR_applyAnimalUIToggle)
