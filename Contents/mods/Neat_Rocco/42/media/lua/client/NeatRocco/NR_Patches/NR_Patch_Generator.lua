-- NR_Patch_Generator.lua
-- Monkey-patches ISGeneratorInfoAction.perform to open NR_GeneratorPanel.

require "NeatRocco/NR_Generator/NR_GeneratorPanel"

ISGeneratorInfoAction._NR_old_perform = ISGeneratorInfoAction._NR_old_perform or ISGeneratorInfoAction.perform

local function NR_performGenerator(self)
    local existing = NR_GeneratorPanel.panels[self.character]

    -- If the existing panel targets a different object, close it first
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

    -- Required: remove the action from the queue (like vanilla)
    ISBaseTimedAction.perform(self)
end

local function NR_applyGeneratorToggle(enabled)
    if enabled then
        ISGeneratorInfoAction.perform = NR_performGenerator
    else
        ISGeneratorInfoAction.perform = ISGeneratorInfoAction._NR_old_perform
        for _, panel in pairs(NR_GeneratorPanel.panels) do
            if panel then panel:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyGeneratorToggle)
