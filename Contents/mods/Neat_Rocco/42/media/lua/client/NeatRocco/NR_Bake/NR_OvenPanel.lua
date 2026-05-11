-- NR_OvenPanel.lua
-- NeatUI-styled replacement for ISOvenUI.
-- Vanilla logic preserved 1:1 — visual layer only.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_OvenPanel = NR_BasePanel:derive("NR_OvenPanel")
NR_OvenPanel.instance = {}  -- keyed by playerNum + 1

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:new(x, y, width, height, oven, character)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    local player = character:getPlayerNum()
    NR_BasePanel.centerOnPlayer(o, character, width, height)

    o.character      = character
    o.playerNum      = player
    o.oven           = oven
    o.knobTex        = getTexture("media/ui/Knobs/KnobDial.png")
    o.hasPowerButton = true

    NR_BasePanel.initBase(o)

    NR_OvenPanel.instance[player + 1] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:getWindowTitle()
    return getText("IGUI_ContainerTitle_stove")
end

function NR_OvenPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Oven.png")
end

function NR_OvenPanel:getHeaderPowerState()
    local isPowered = self.oven:getContainer() and self.oven:getContainer():isPowered()
    if not isPowered then return "disabled" end
    return self.oven:Activated() and "on" or "off"
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:createChildren()
    local hh      = NR_Config.headerHeight
    local pad     = NR_Config.padding

    NR_BasePanel.createChildren(self)

    -- Temperature knob (vanilla ISKnob — textures and behaviour preserved)
    self.tempKnob = ISKnob:new(pad, hh + pad, self.knobTex, getTexture("media/ui/Knobs/KnobBGFarhenOvenTemp.png"), getText("IGUI_Temperature"), self.character)
    self.tempKnob:initialise()
    self.tempKnob:instantiate()
    self.tempKnob.onMouseUpFct = NR_OvenPanel.ChangeKnob
    self.tempKnob.target       = self
    self.tempKnob.switchSound  = "ToggleTemp"
    self:addChild(self.tempKnob)

    -- C / F buttons (NI_SquareButton style — carré, orange = actif, gris = inactif)
    local bsz = NR_Config.buttonSize
    local tbY = self.tempKnob.y + self.tempKnob.height + pad

    local bgTex  = getTexture("media/ui/NeatUI/Button/Background.png")
    local brdTex = getTexture("media/ui/NeatUI/Button/Boarder.png")

    local function makeUnitBtnPrerender(label, isCelsiusBtn)
        return function(btn)
            local active = (isCelsiusBtn == getCore():isCelsius())
            local hover  = btn:isMouseOver()
            local r, g, b2
            if active then
                r, g, b2 = 0.95, 0.5, 0.1
                if hover then r, g, b2 = math.min(r*1.2,1), math.min(g*1.2,1), math.min(b2*1.2,1) end
            else
                local v = hover and 0.3 or 0.2
                r, g, b2 = v, v, v
            end
            btn:drawTextureScaled(bgTex,  0, 0, bsz, bsz, 0.8, r, g, b2)
            btn:drawTextureScaled(brdTex, 0, 0, bsz, bsz, 1, 0.4, 0.4, 0.4)
            local fh = getTextManager():getFontHeight(UIFont.Small)
            local fw = getTextManager():MeasureStringX(UIFont.Small, label)
            btn:drawText(label, math.floor((bsz - fw) / 2), math.floor((bsz - fh) / 2), 1, 1, 1, 1, UIFont.Small)
        end
    end

    self.celsiusBtn = ISButton:new(pad, tbY, bsz, bsz, "", self, NR_OvenPanel.onClickCelsius)
    self.celsiusBtn:initialise()
    self.celsiusBtn:setDisplayBackground(false)
    self.celsiusBtn.prerender = makeUnitBtnPrerender("C", true)
    self:addChild(self.celsiusBtn)

    self.fahrenheitBtn = ISButton:new(20 + bsz + pad, tbY, bsz, bsz, "", self, NR_OvenPanel.onClickFahrenheit)
    self.fahrenheitBtn:initialise()
    self.fahrenheitBtn:setDisplayBackground(false)
    self.fahrenheitBtn.prerender = makeUnitBtnPrerender("F", false)
    self:addChild(self.fahrenheitBtn)

    self:changeTempType()

    -- Timer knob (vanilla ISKnob)
    local texBG = getTexture("media/ui/Knobs/KnobBGOvenTimer.png")
    self.timerKnob = ISKnob:new(self.tempKnob.x + self.tempKnob.width + pad, hh + pad, self.knobTex, texBG, getText("IGUI_Timer"), self.character)
    self.timerKnob:initialise()
    self.timerKnob:instantiate()
    self.timerKnob.onMouseUpFct = NR_OvenPanel.ChangeKnob
    self.timerKnob.target       = self
    self:addChild(self.timerKnob)

    self:setHeight(self.celsiusBtn:getBottom() + pad)

    self:addKnobValues()
    self:updateButtons()

    self:insertNewLineOfButtons(self.tempKnob, self.timerKnob)
    self:insertNewLineOfButtons(self.celsiusBtn, self.fahrenheitBtn)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle (suite)
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:update()
    self:updateButtons()
    if self.character:DistTo(self.oven:getX(), self.oven:getY()) > 3 then
        self:close()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla logic — preserved 1:1
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:onClickCelsius()
    getCore():setCelsius(true)
    getCore():saveOptions()
    self:changeTempType()
end

function NR_OvenPanel:onClickFahrenheit()
    getCore():setCelsius(false)
    getCore():saveOptions()
    self:changeTempType()
end

function NR_OvenPanel:changeTempType()
    if not getCore():isCelsius() then
        self.tempKnob.valuesBg = getTexture("media/ui/Knobs/KnobBGFarhenOvenTemp.png")
    else
        self.tempKnob.valuesBg = getTexture("media/ui/Knobs/KnobBGCelciusOvenTemp.png")
    end
end

function NR_OvenPanel:ChangeKnob()
    self.oven:setMaxTemperature(self.tempKnob:getValue())
    self.oven:setTimer(self.timerKnob:getValue() * 60)
    local sync = false
    if not self.timerKnob.dragging and not self.tempKnob.dragging then
        self.oven:sync()
        sync = true
    end
    self.oven:syncSpriteGridObjects(false, sync)
end

function NR_OvenPanel:updateButtons()
    if not self.timerKnob.dragging then
        if self.oven:isRunningFor() > 0 then
            self.timerKnob:setKnobPosition(math.ceil((self.oven:getTimer() - self.oven:isRunningFor()) / 60))
        else
            self.timerKnob:setKnobPosition(self.oven:getTimer() / 60)
        end
    end
    if not self.tempKnob.dragging then
        self.tempKnob:setKnobPosition(self.oven:getMaxTemperature())
    end
end

function NR_OvenPanel:addKnobValues()
    self.tempKnob:addValue(0,   0)
    self.tempKnob:addValue(45,  50)
    self.tempKnob:addValue(90,  100)
    self.tempKnob:addValue(135, 150)
    self.tempKnob:addValue(180, 200)
    self.tempKnob:addValue(225, 250)
    self.tempKnob:addValue(270, 300)

    self.timerKnob:addValue(0,   0)
    self.timerKnob:addValue(18,  1)
    self.timerKnob:addValue(36,  2)
    self.timerKnob:addValue(54,  3)
    self.timerKnob:addValue(72,  4)
    self.timerKnob:addValue(90,  5)
    self.timerKnob:addValue(108, 10)
    self.timerKnob:addValue(126, 15)
    self.timerKnob:addValue(144, 20)
    self.timerKnob:addValue(162, 25)
    self.timerKnob:addValue(180, 30)
    self.timerKnob:addValue(198, 40)
    self.timerKnob:addValue(216, 50)
    self.timerKnob:addValue(234, 60)
    self.timerKnob:addValue(252, 90)
    self.timerKnob:addValue(270, 120)
end

function NR_OvenPanel:onClickPower()
    local isPowered = self.oven:getContainer() and self.oven:getContainer():isPowered()
    if not isPowered then return end
    local args = {
        x = self.oven:getX(), y = self.oven:getY(), z = self.oven:getZ(),
        timer = self.timerKnob:getValue() * 60,
        maxTemperature = self.tempKnob:getValue()
    }
    sendClientCommand(self.character, 'stove', 'setOvenParamsAndToggle', args)
end

function NR_OvenPanel:close()
    NR_OvenPanel.instance[self.playerNum + 1] = nil
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_OvenPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.joypadIndexY = 1
    self.joypadIndex  = 1
    self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
    self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function NR_OvenPanel:onJoypadDown(button, joypadData)
    if button == Joypad.AButton then self:onClickPower() ; return end
    NR_BasePanel.onJoypadDown(self, button, joypadData)
end

-- (prerender, render, onLoseJoypadFocus, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
