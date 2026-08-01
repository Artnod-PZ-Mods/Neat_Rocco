-- NR_BombTimerDialog.lua
-- NeatUI-styled override of ISBombTimerDialog.
-- Derives from ISBombTimerDialog so all logic (timer, joypad, destroy) is inherited.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_BombTimerDialog = ISBombTimerDialog:derive("NR_BombTimerDialog")

-- ----------------------------------------------------------------------------------------------------- --
-- initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_BombTimerDialog:initialise()
    ISBombTimerDialog.initialise(self)

    local pad   = NR_Config.padding
    local btnSz = NR_Config.buttonSize

    -- Use vanilla button height as size for +/- buttons to preserve layout
    local arrowSz = self.button1p:getHeight()

    local function makeTimerBtn(vanillaBtn, icon, callback)
        vanillaBtn:setVisible(false)
        local x = vanillaBtn:getX() + math.floor((vanillaBtn:getWidth()  - arrowSz) / 2)
        local y = vanillaBtn:getY() + math.floor((vanillaBtn:getHeight() - arrowSz) / 2)
        local btn = NI_SquareButton:new(x, y, arrowSz, icon, self, callback)
        btn:initialise()
        btn:setActive(true)
        self:addChild(btn)
        return btn
    end

    local iconMinus10 = getTexture("media/ui/NeatRocco/ICON/Icon_Minus10.png")
    local iconMinus5  = getTexture("media/ui/NeatRocco/ICON/Icon_Minus5.png")
    local iconMinus1  = getTexture("media/ui/NeatRocco/ICON/Icon_Minus1.png")
    local iconPlus1   = getTexture("media/ui/NeatRocco/ICON/Icon_Plus1.png")
    local iconPlus5   = getTexture("media/ui/NeatRocco/ICON/Icon_Plus5.png")
    local iconPlus10  = getTexture("media/ui/NeatRocco/ICON/Icon_Plus10.png")

    self.neatBtn10m = makeTimerBtn(self.button10m, iconMinus10, function() self:onButton(self.button10m) end)
    self.neatBtn5m  = makeTimerBtn(self.button5m,  iconMinus5,  function() self:onButton(self.button5m)  end)
    self.neatBtn1m  = makeTimerBtn(self.button1m,  iconMinus1,  function() self:onButton(self.button1m)  end)
    self.neatBtn1p  = makeTimerBtn(self.button1p,  iconPlus1,   function() self:onButton(self.button1p)  end)
    self.neatBtn5p  = makeTimerBtn(self.button5p,  iconPlus5,   function() self:onButton(self.button5p)  end)
    self.neatBtn10p = makeTimerBtn(self.button10p, iconPlus10,  function() self:onButton(self.button10p) end)

    local uiElemBG = {
        left   = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png"),
        middle = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png"),
        right  = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png"),
    }
    local boxShift = math.floor(pad / 2)
    self.textBox:setX(self.textBox:getX() + boxShift)
    self.textBox.prerender = function(b)
        NeatTool.ThreePatch.drawHorizontal(
            b, -boxShift, 0, b.width, b.height,
            uiElemBG.left, uiElemBG.middle, uiElemBG.right,
            1, 0.4, 0.4, 0.4
        )
    end

    -- Hide vanilla Ok/Cancel buttons — joypad still uses them via insertNewLineOfButtons
    self.yes:setVisible(false)
    self.no:setVisible(false)

    local btnY = self.height - btnSz - pad
    local yesX = math.floor(self.width / 2) - btnSz - math.floor(pad / 2)
    self.iconYes = NI_SquareButton:new(yesX, btnY, btnSz,
        getTexture("media/ui/NeatUI/Icon/Icon_True.png"), self,
        function() self:onButton(self.yes) end)
    self.iconYes:initialise()
    self.iconYes:setActive(true)
    self.iconYes:setActiveColor(0.2, 0.75, 0.2)
    self:addChild(self.iconYes)

    local noX = math.floor(self.width / 2) + math.floor(pad / 2)
    self.iconNo = NI_SquareButton:new(noX, btnY, btnSz,
        getTexture("media/ui/NeatUI/Icon/Icon_False.png"), self,
        function() self:onButton(self.no) end)
    self.iconNo:initialise()
    self.iconNo:setActive(true)
    self.iconNo:setActiveColor(0.8, 0.2, 0.2)
    self:addChild(self.iconNo)
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + prompt text
-- ----------------------------------------------------------------------------------------------------- --

function NR_BombTimerDialog:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, 0.12, 0.12, 0.12, NR_Config.bgAlpha)
    else
        self:drawRect(0, 0, self.width, self.height, 0.95, 0.12, 0.12, 0.12)
    end
    self:drawTextCentre(self.prompt, self:getWidth() / 2, 20, 1, 1, 1, 1, UIFont.Small)
end
