-- NR_TextBox.lua
-- NeatUI-styled override of ISTextBox.
-- Derives from ISTextBox so all logic (entry field, validation, joypad, callbacks) is inherited.
-- Strategy: call ISTextBox.initialise() to create vanilla yes/no ISButton (needed for joypad),
-- hide them, then add NI_SquareButton on top for mouse — same pattern as NR_ConfirmDialog.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_TextBox = ISTextBox:derive("NR_TextBox")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_TextBox:initialise()
    -- Create vanilla yes/no ISButton (needed for joypad via onGainJoypadFocus / updateButtons)
    ISTextBox.initialise(self)

    local pad   = NR_Config.padding
    local btnSz = NR_Config.buttonSize
    local btnY  = self.height - btnSz - pad

    -- Hide vanilla buttons — joypad still uses them via setISButtonForA/B
    self.yes:setVisible(false)
    self.no:setVisible(false)

    -- OK icon button — mouse only (green)
    local okX = math.floor(self.width / 2) - btnSz - pad
    self.iconOk = NI_SquareButton:new(okX, btnY, btnSz,
        getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
        function() ISTextBox.onClick(self, { internal = "OK", parent = self }) end)
    self.iconOk:initialise()
    self.iconOk:setActive(true)
    self.iconOk:setActiveColor(0.2, 0.75, 0.2)
    self:addChild(self.iconOk)

    -- Cancel icon button — mouse only (red)
    local cancelX = math.floor(self.width / 2) + pad
    self.iconCancel = NI_SquareButton:new(cancelX, btnY, btnSz,
        getTexture("media/ui/NeatUI/Icon/Icon_False.png"), self,
        function() ISTextBox.onClick(self, { internal = "CANCEL", parent = self }) end)
    self.iconCancel:initialise()
    self.iconCancel:setActive(true)
    self.iconCancel:setActiveColor(0.8, 0.2, 0.2)
    self:addChild(self.iconCancel)
end

-- ----------------------------------------------------------------------------------------------------- --
-- updateButtons — mirror vanilla yes.enable to iconOk
-- ----------------------------------------------------------------------------------------------------- --

function NR_TextBox:updateButtons()
    ISTextBox.updateButtons(self)
    if self.iconOk then
        local enabled = (self.yes.enable ~= false)
        self.iconOk.enable = enabled
        self.iconOk:setActive(enabled)
        if enabled then
            self.iconOk:setActiveColor(0.2, 0.75, 0.2)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + prompt text
-- ----------------------------------------------------------------------------------------------------- --

function NR_TextBox:prerender()
    -- Main panel background
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        local c = NR_Config.panelBg
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, c, c, c, NR_Config.bgAlpha)
    else
        local c = NR_Config.panelBg
        self:drawRect(0, 0, self.width, self.height, 0.95, c, c, c)
    end

    -- Title bar background
    local th    = self:titleBarHeight()
    local title = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
    if title then
        local c = NR_Config.headerBg
        title:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, th + 2, c, c, c, 1)
    end
    self:drawRect(0, th, self.width, 2, 1, 0, 0, 0)

    -- Prompt text (centred in title bar)
    self:drawTextCentre(self.text, self:getWidth() / 2, 3, 1, 1, 1, 1, UIFont.Small)

    -- Validation error
    if self.showError then
        self:drawTextCentre(
            self.errorMsg,
            self:getWidth() / 2,
            self.entry:getY() + 50 - FONT_HGT_SMALL,
            1, 0, 0, 1, UIFont.Small
        )
    end

    self:updateButtons()
end
