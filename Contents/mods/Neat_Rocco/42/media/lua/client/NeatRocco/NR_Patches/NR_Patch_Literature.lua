-- NR_Patch_Literature.lua
-- Monkey-patches ISCharacterScreen.onShowLiterature to open NR_LiteraturePanel.

require "NeatRocco/NR_Literature/NR_LiteraturePanel"

ISCharacterScreen._NR_old_onShowLiterature = ISCharacterScreen._NR_old_onShowLiterature or ISCharacterScreen.onShowLiterature

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

NR_RegisterToggleCallback(NR_applyLiteratureToggle)
