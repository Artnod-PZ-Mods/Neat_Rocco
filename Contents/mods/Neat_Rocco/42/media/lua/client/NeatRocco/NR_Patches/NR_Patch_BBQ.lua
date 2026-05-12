-- NR_Patch_BBQ.lua
-- Monkey-patches ISBBQInfoAction.perform and ISBBQRemovePropaneTank.perform.

require "NeatRocco/NR_BBQ/NR_BBQPanel"

ISBBQInfoAction._NR_old_perform        = ISBBQInfoAction._NR_old_perform        or ISBBQInfoAction.perform
ISBBQRemovePropaneTank._NR_old_perform = ISBBQRemovePropaneTank._NR_old_perform or ISBBQRemovePropaneTank.perform

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

NR_RegisterToggleCallback(NR_applyBBQToggle)
