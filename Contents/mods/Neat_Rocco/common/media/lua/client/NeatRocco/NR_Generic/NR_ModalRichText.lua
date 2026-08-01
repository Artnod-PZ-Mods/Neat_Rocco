-- NR_ModalRichText.lua
-- NeatUI-styled override of ISModalRichText.
-- No header: the panel is a rounded NeatUI rectangle holding the rich text
-- (full raw text, no title/body split) and one or two NI_SquareButton at the
-- bottom:
--   yesno=false → single green OK button, centered
--   yesno=true  → green YES on the left, red NO on the right
-- Visibility of vanilla buttons vs NI is driven by ensureIcons() at each
-- prerender (vanilla shown as fallback while NeatUI icon textures load).

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_ScrollingList"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_ModalRichText = ISModalRichText:derive("NR_ModalRichText")

-- ----------------------------------------------------------------------------------------------------- --
-- bottomReserve — vertical space below chatText for the buttons row.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:bottomReserve()
    return NR_Config.buttonSize + NR_Config.padding * 2
end

-- ----------------------------------------------------------------------------------------------------- --
-- initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:initialise()
    -- Create vanilla ok (or yes/no) ISButton + chatText (needed for joypad + scroll logic)
    ISModalRichText.initialise(self)

    -- Cache original positions of vanilla buttons so we can move them off-screen
    -- (rather than setVisible(false)) once NI textures are ready. Off-screen keeps
    -- getIsVisible()==true so forceClick() still works — important because vanilla
    -- code such as ISWorldMap:close() does `self.forgetUI.no:forceClick()` on ESC.
    if self.yesno then
        self._yesOrigX, self._yesOrigY = self.yes:getX(), self.yes:getY()
        self._noOrigX,  self._noOrigY  = self.no:getX(),  self.no:getY()
    else
        self._okOrigX,  self._okOrigY  = self.ok:getX(),  self.ok:getY()
    end

    local pad   = NR_Config.padding
    local btnSz = NR_Config.buttonSize
    local btnY  = self.height - btnSz - pad

    if self.yesno then
        local yesX = math.floor(self.width / 2) - btnSz - pad
        self.iconYes = NI_SquareButton:new(yesX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
            function() ISModalRichText.onClick(self, { internal = "YES" }) end)
        self.iconYes:initialise()
        self.iconYes:setActive(true)
        self.iconYes:setActiveColor(0.2, 0.75, 0.2)
        self:addChild(self.iconYes)

        local noX = math.floor(self.width / 2) + pad
        self.iconNo = NI_SquareButton:new(noX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_False.png"), self,
            function() ISModalRichText.onClick(self, { internal = "NO" }) end)
        self.iconNo:initialise()
        self.iconNo:setActive(true)
        self.iconNo:setActiveColor(0.8, 0.2, 0.2)
        self:addChild(self.iconNo)
    else
        local okX = math.floor((self.width - btnSz) / 2)
        self.iconOk = NI_SquareButton:new(okX, btnY, btnSz,
            getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
            function() ISModalRichText.onClick(self, { internal = "OK" }) end)
        self.iconOk:initialise()
        self.iconOk:setActive(true)
        self.iconOk:setActiveColor(0.2, 0.75, 0.2)
        self:addChild(self.iconOk)
    end

    -- chatText fills the panel from a small top inset, leaving room for buttons at the bottom
    self.chatText:setY(pad)
    self.chatText:setHeight(self.height - pad - self:bottomReserve())
    if self.chatText.vscroll then
        NR_ScrollingList.applyNeatStyle(self.chatText.vscroll)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- ensureIcons — retry getTexture if textures were not ready at initialise(),
-- and toggle vanilla buttons ↔ NI buttons based on icon readiness.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:ensureIcons()
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
            if ready then
                -- Move vanilla off-screen so forceClick() keeps working (ESC path)
                self.yes:setX(-9999); self.yes:setY(-9999)
                self.no:setX(-9999);  self.no:setY(-9999)
            else
                -- Restore vanilla positions for fallback rendering
                self.yes:setX(self._yesOrigX); self.yes:setY(self._yesOrigY)
                self.no:setX(self._noOrigX);   self.no:setY(self._noOrigY)
            end
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
            if ready then
                self.ok:setX(-9999); self.ok:setY(-9999)
            else
                self.ok:setX(self._okOrigX); self.ok:setY(self._okOrigY)
            end
            self.iconOk:setVisible(ready)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- updateButtons — reposition NI buttons after a height change.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:updateButtons()
    local pad   = NR_Config.padding
    local btnSz = NR_Config.buttonSize
    local btnY  = self.height - btnSz - pad
    if self.yesno then
        if self.iconYes then self.iconYes:setY(btnY) end
        if self.iconNo  then self.iconNo:setY(btnY)  end
    else
        if self.iconOk then self.iconOk:setY(btnY) end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- setHeightToContents — account for top inset + bottom button reserve.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:setHeightToContents()
    local minHeight = self.chatText:getScrollHeight() + NR_Config.padding + self:bottomReserve()
    self:setHeight(minHeight)
    self:ignoreHeightChange()
    self:updateButtons()
end

-- ----------------------------------------------------------------------------------------------------- --
-- update — auto-resize window, keep chatText filling the space.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:update()
    ISPanelJoypad.update(self)

    local pad       = NR_Config.padding
    local reserve   = self:bottomReserve()
    local maxHeight = getCore():getScreenHeight() - 40
    local minHeight = math.min(self.chatText:getScrollHeight() + pad + reserve, maxHeight)

    if self:getHeight() < minHeight then
        local dh = minHeight - self:getHeight()
        self:setHeight(minHeight)
        self:ignoreHeightChange()
        self:setY(math.max(self:getY() - dh / 2, 20))
        self:updateButtons()
    elseif self:getHeight() > maxHeight then
        self:setHeight(maxHeight)
        self:ignoreHeightChange()
        self:setY(20)
        self:updateButtons()
    end

    self.chatText:setHeight(self.height - pad - reserve)
    self.chatText:updateScrollbars()

    if self.alwaysOnTop then
        self:bringToTop()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI rounded background, full panel.
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:prerender()
    self:ensureIcons()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        local c = NR_Config.panelBg
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, c, c, c, NR_Config.bgAlpha)
    else
        local c = NR_Config.panelBg
        self:drawRect(0, 0, self.width, self.height, 0.95, c, c, c)
    end
end
