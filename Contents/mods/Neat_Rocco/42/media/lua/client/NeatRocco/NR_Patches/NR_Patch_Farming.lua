-- NR_Patch_Farming.lua
-- Monkey-patches ISPlantInfoAction.perform to open NR_PlantPanel.

require "NeatRocco/NR_Farming/NR_PlantPanel"

ISPlantInfoAction._NR_old_perform = ISPlantInfoAction._NR_old_perform or ISPlantInfoAction.perform

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

local function NR_applyFarmingToggle(enabled)
    if enabled then
        ISPlantInfoAction.perform = NR_performPlantInfo
    else
        ISPlantInfoAction.perform = ISPlantInfoAction._NR_old_perform
        for _, panel in pairs(NR_PlantPanel.panels) do
            if panel then panel:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyFarmingToggle)
