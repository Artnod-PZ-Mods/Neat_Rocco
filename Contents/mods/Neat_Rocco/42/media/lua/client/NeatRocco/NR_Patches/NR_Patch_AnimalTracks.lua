-- NR_Patch_AnimalTracks.lua
-- Monkey-patches ISInspectAnimalTrackAction.perform to open NR_AnimalTracksPanel.

require "NeatRocco/NR_AnimalTracks/NR_AnimalTracksPanel"

ISInspectAnimalTrackAction._NR_old_perform = ISInspectAnimalTrackAction._NR_old_perform or ISInspectAnimalTrackAction.perform

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

NR_RegisterToggleCallback(NR_applyAnimalTracksToggle)
