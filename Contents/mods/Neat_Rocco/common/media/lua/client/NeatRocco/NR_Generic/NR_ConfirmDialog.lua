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

    -- Visibility of vanilla vs NI buttons is driven by ensureIcons() at each
    -- prerender, so the dialog always shows usable buttons (vanilla as
    -- fallback while NeatUI icon textures load).
    if self.yesno then
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
-- ensureIcons — retry getTexture if textures were not ready at initialise(),
-- and toggle vanilla buttons ↔ NI buttons based on icon readiness so the
-- dialog never shows itself without usable buttons.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ConfirmDialog:ensureIcons()
    if self.yesno then
        if self.iconYes and not self.iconYes.iconTexture then
            self.iconYes:setIcon(getTexture("media/ui/NeatUI/Icon/Icon_True.png"))
        end
        if self.iconNo and not self.iconNo.iconTexture then
            self.iconNo:setIcon(getTexture("media/ui/NeatUI/Icon/Icon_False.png"))
        end

        local ready = (self.iconYes and self.iconYes.iconTexture
                  and self.iconNo and self.iconNo.iconTexture) ~= nil
        if ready ~= self._iconsReady then
            self._iconsReady = ready
            self.yes:setVisible(not ready)
            self.no:setVisible(not ready)
            self.iconYes:setVisible(ready)
            self.iconNo:setVisible(ready)
        end
    else
        if self.iconOk and not self.iconOk.iconTexture then
            self.iconOk:setIcon(getTexture("media/ui/NeatUI/Icon/Icon_True.png"))
        end

        local ready = (self.iconOk and self.iconOk.iconTexture) ~= nil
        if ready ~= self._iconsReady then
            self._iconsReady = ready
            self.ok:setVisible(not ready)
            self.iconOk:setVisible(ready)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + prompt text
-- ----------------------------------------------------------------------------------------------------- --

function NR_ConfirmDialog:prerender()
    self:ensureIcons()
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
