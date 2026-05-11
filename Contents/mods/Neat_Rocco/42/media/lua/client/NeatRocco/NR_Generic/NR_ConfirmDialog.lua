-- NR_ConfirmDialog.lua
-- NeatUI-styled override of ISModalDialog.
-- Derives from ISModalDialog so all logic (callbacks, joypad, destroy) is inherited.
-- Strategy: call ISModalDialog.initialise() to create vanilla yes/no ISButton instances,
-- hide them (kept invisible for joypad compatibility), then add NI_SquareButton on top for mouse.
-- This way onGainJoypadFocus / onLoseJoypadFocus from ISModalDialog work without modification.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_ConfirmDialog = ISModalDialog:derive("NR_ConfirmDialog")

-- ----------------------------------------------------------------------------------------------------- --
-- initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_ConfirmDialog:initialise()
    -- Create vanilla yes/no/ok ISButton instances (needed for joypad via onGainJoypadFocus)
    ISModalDialog.initialise(self)

    local pad   = NR_Config.padding
    local btnSz = NR_Config.buttonSize
    local btnY  = self.height - btnSz - pad

    if self.yesno then
        -- Hide vanilla text buttons — joypad still uses them via setISButtonForA/B
        self.yes:setVisible(false)
        self.no:setVisible(false)

        -- YES icon button — mouse only (green)
        local yesX = math.floor(self.width / 2) - btnSz - pad
        self.iconYes = NI_SquareButton:new(yesX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
            function() ISModalDialog.onClick(self, { internal = "YES", player = self.player, parent = self }) end)
        self.iconYes:initialise()
        self.iconYes:setActive(true)
        self.iconYes:setActiveColor(0.2, 0.75, 0.2)
        self:addChild(self.iconYes)

        -- NO icon button — mouse only (red)
        local noX = math.floor(self.width / 2) + pad
        self.iconNo = NI_SquareButton:new(noX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_False.png"), self,
            function() ISModalDialog.onClick(self, { internal = "NO", player = self.player, parent = self }) end)
        self.iconNo:initialise()
        self.iconNo:setActive(true)
        self.iconNo:setActiveColor(0.8, 0.2, 0.2)
        self:addChild(self.iconNo)
    else
        -- Hide vanilla ok button
        self.ok:setVisible(false)

        -- OK icon button — mouse only (green, centred)
        local okX = math.floor((self.width - btnSz) / 2)
        self.iconOk = NI_SquareButton:new(okX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
            function() ISModalDialog.onClick(self, { internal = "OK", player = self.player, parent = self }) end)
        self.iconOk:initialise()
        self.iconOk:setActive(true)
        self.iconOk:setActiveColor(0.2, 0.75, 0.2)
        self:addChild(self.iconOk)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + prompt text
-- ----------------------------------------------------------------------------------------------------- --

function NR_ConfirmDialog:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        local c = NR_Config.panelBg
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, c, c, c, NR_Config.bgAlpha)
    else
        local c = NR_Config.panelBg
        self:drawRect(0, 0, self.width, self.height, 0.95, c, c, c)
    end
    self:drawTextCentre(self.text, self:getWidth() / 2, 20, 1, 1, 1, 1, UIFont.Small)
end
