-- NR_MicrowavePanel.lua
-- NeatUI-styled replacement for ISMicrowaveUI.
-- Vanilla logic preserved 1:1 — visual layer only.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_MicrowavePanel = NR_BasePanel:derive("NR_MicrowavePanel")
NR_MicrowavePanel.instance = {}  -- keyed by playerNum + 1

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:new(x, y, width, height, oven, character)
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

    NR_MicrowavePanel.instance[player + 1] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:getWindowTitle()
    return getText("IGUI_ContainerTitle_microwave")
end

function NR_MicrowavePanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Microwave.png")
end

function NR_MicrowavePanel:getHeaderPowerState()
    local isPowered = self.oven:getContainer() and self.oven:getContainer():isPowered()
    if not isPowered then return "disabled" end
    return self.oven:Activated() and "on" or "off"
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:createChildren()
    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding

    NR_BasePanel.createChildren(self)

    -- Temperature knob (vanilla ISKnob — textures and behaviour preserved)
    self.tempKnob = ISKnob:new(pad, hh + pad, self.knobTex, getTexture("media/ui/Knobs/KnobBGMicrowaveTemp.png"), getText("IGUI_Temperature"), self.character)
    self.tempKnob:initialise()
    self.tempKnob:instantiate()
    self.tempKnob.onMouseUpFct = NR_MicrowavePanel.ChangeKnob
    self.tempKnob.target       = self
    self.tempKnob.switchSound  = "ToggleTemp"
    self:addChild(self.tempKnob)

    -- Timer knob (vanilla ISKnob)
    local texBG = getTexture("media/ui/Knobs/KnobBGMicrowaveTimer.png")
    self.timerKnob = ISKnob:new(self.tempKnob.x + self.tempKnob.width + pad, hh + pad, self.knobTex, texBG, getText("IGUI_Timer"), self.character)
    self.timerKnob:initialise()
    self.timerKnob:instantiate()
    self.timerKnob.onMouseUpFct = NR_MicrowavePanel.ChangeKnob
    self.timerKnob.target       = self
    self:addChild(self.timerKnob)

    self:setHeight(self.tempKnob:getBottom() + pad)

    self:addKnobValues()
    self:updateButtons()

    self:insertNewLineOfButtons(self.tempKnob, self.timerKnob)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle (suite)
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:update()
    self:updateButtons()
    if self.character:DistTo(self.oven:getX(), self.oven:getY()) > 3 then
        self:close()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla logic — preserved 1:1
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:ChangeKnob()
    self.oven:setMaxTemperature(self.tempKnob:getValue())
    self.oven:setTimer(self.timerKnob:getValue() * 60)
    if not self.timerKnob.dragging and not self.tempKnob.dragging then
        self.oven:sync()
    end
end

function NR_MicrowavePanel:updateButtons()
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

function NR_MicrowavePanel:addKnobValues()
    self.tempKnob:addValue(0,   90)
    self.tempKnob:addValue(45,  110)
    self.tempKnob:addValue(90,  130)
    self.tempKnob:addValue(270, 50)
    self.tempKnob:addValue(315, 70)

    self.timerKnob:addValue(0,   0)
    self.timerKnob:addValue(18,  1)
    self.timerKnob:addValue(36,  2)
    self.timerKnob:addValue(54,  3)
    self.timerKnob:addValue(72,  4)
    self.timerKnob:addValue(90,  5)
    self.timerKnob:addValue(108, 6)
    self.timerKnob:addValue(126, 7)
    self.timerKnob:addValue(144, 8)
    self.timerKnob:addValue(162, 9)
    self.timerKnob:addValue(180, 10)
    self.timerKnob:addValue(198, 15)
    self.timerKnob:addValue(216, 20)
    self.timerKnob:addValue(234, 25)
    self.timerKnob:addValue(252, 30)
    self.timerKnob:addValue(270, 45)
    self.timerKnob:addValue(288, 60)
end

function NR_MicrowavePanel:onClickPower()
    local isPowered = self.oven:getContainer() and self.oven:getContainer():isPowered()
    if not isPowered then return end
    local args = {
        x = self.oven:getX(), y = self.oven:getY(), z = self.oven:getZ(),
        timer = self.timerKnob:getValue() * 60,
        maxTemperature = self.tempKnob:getValue()
    }
    sendClientCommand(self.character, 'stove', 'setOvenParamsAndToggle', args)
end

function NR_MicrowavePanel:close()
    NR_MicrowavePanel.instance[self.playerNum + 1] = nil
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_MicrowavePanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.joypadIndexY = 1
    self.joypadIndex  = 1
    self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
    self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function NR_MicrowavePanel:onJoypadDown(button, joypadData)
    if button == Joypad.AButton then self:onClickPower() ; return end
    NR_BasePanel.onJoypadDown(self, button, joypadData)
end

-- (prerender, render, onLoseJoypadFocus, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
