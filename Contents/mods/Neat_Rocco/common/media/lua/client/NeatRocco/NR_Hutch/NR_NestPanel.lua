-- NR_NestPanel.lua
-- NeatUI replacement for ISHutchNestParentPanel.
-- Displays the egg-laying nest boxes. ISHutchNestBox panels are reused as-is (vanilla).

require "NeatRocco/NR_Config"

NR_NestPanel = ISPanelJoypad:derive("NR_NestPanel")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- Vanilla constants (fixed, not font-based — must match ISHutchUI.lua exactly)
local NEST_BOX_WIDTH    = 160
local NEST_BOX_HEIGHT   = 130
local PADXY             = 20
local UI_BORDER_SPACING = 10

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:new(x, y, width, height, hutchUI)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.hutchUI              = hutchUI
    o.disableJoypadNavigation = true  -- same as vanilla
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:createChildren()
    local bsz = NR_Config.buttonSize

    -- Grid of ISHutchNestBox (vanilla, reused as-is)
    local numNestBoxes   = self.hutchUI.hutch:getMaxNestBox() + 1  -- zero-based, max=3 → 4 boxes
    local boxPerRow      = 2
    local requiredNestWid = NEST_BOX_WIDTH * boxPerRow + UI_BORDER_SPACING * (boxPerRow - 1)
    local boxX1          = math.floor((self.width - requiredNestWid) / 2)
    local boxY1          = PADXY

    self.nestBoxUI = {}
    for i = 1, numNestBoxes do
        local nestBoxUI = ISHutchNestBox:new(boxX1, boxY1, NEST_BOX_WIDTH, NEST_BOX_HEIGHT, self.hutchUI, i - 1)
        self:addChild(nestBoxUI)
        table.insert(self.nestBoxUI, nestBoxUI)
        boxX1 = boxX1 + NEST_BOX_WIDTH + 10
        if i % boxPerRow == 0 then
            boxX1 = math.floor((self.width - requiredNestWid) / 2)
            boxY1 = boxY1 + NEST_BOX_HEIGHT + 10
        end
    end

    -- Egg hatch door button (NI_SquareButton, orange) — positioned each frame in prerender()
    self.eggHatchDoorBtn = NI_SquareButton:new(
        self.width - PADXY - bsz,
        self.height - UI_BORDER_SPACING - bsz,
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Door.png"),
        self, NR_NestPanel.onToggleEggHatchDoor
    )
    self.eggHatchDoorBtn:initialise()
    self.eggHatchDoorBtn:setActive(true)
    self.eggHatchDoorBtn:setActiveColor(0.95, 0.5, 0.1)
    self:addChild(self.eggHatchDoorBtn)

    -- Closed door overlay panel (dark NeatUI background — door access blocked)
    self.closedDoorPanel = ISPanel:new(0, 0, self.width, self.height)
    self.closedDoorPanel:noBackground()
    function self.closedDoorPanel:prerender()
        local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
        if bg then
            bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, 0.08, 0.08, 0.08, NR_Config.bgAlpha)
        end
    end
    self.closedDoorPanel:initialise()
    self:addChild(self.closedDoorPanel)
    self.closedDoorPanel:setVisible(false)

    -- Open door button inside overlay (NI_SquareButton, green, 2× size — positive action)
    local bigBsz = bsz * 2
    self.openDoorBtn = NI_SquareButton:new(
        math.floor((self.width - bigBsz) / 2),
        math.floor((self.height - bigBsz) / 2),
        bigBsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Door.png"),
        self, NR_NestPanel.onToggleEggHatchDoor
    )
    self.openDoorBtn:initialise()
    self.openDoorBtn:setActive(true)
    self.openDoorBtn:setActiveColor(0.2, 0.75, 0.2)
    self.closedDoorPanel:addChild(self.openDoorBtn)

    self:configJoypad()
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — reposition door button
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:prerender()
    ISPanelJoypad.prerender(self)
    -- Reposition eggHatchDoorBtn (bottom-right corner)
    self.eggHatchDoorBtn:setX(self.width - PADXY - NR_Config.buttonSize)
    self.eggHatchDoorBtn:setY(self.height - UI_BORDER_SPACING - NR_Config.buttonSize)
end

-- ----------------------------------------------------------------------------------------------------- --
-- render — toggle overlay + update door icon
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:render()
    ISPanelJoypad.render(self)

    -- Overlay: visible when both main door AND egg hatch door are closed
    if self.hutchUI.hutch:isEggHatchDoorOpen() or self.hutchUI.hutch:isOpen() then
        if self.closedDoorPanel:isVisible() then
            self.closedDoorPanel:setVisible(false)
            self:configJoypad()
        end
    else
        if not self.closedDoorPanel:isVisible() then
            self.closedDoorPanel:setWidth(self.width)
            self.closedDoorPanel:setHeight(self.height)
            self.closedDoorPanel:bringToTop()
            self.closedDoorPanel:setVisible(true)
            self:configJoypad()
        end
        return
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Action callbacks
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:onToggleEggHatchDoor()
    self.hutchUI:onToggleEggHatchDoor()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_NestPanel:configJoypad()
    local joypadData = getJoypadData(self.hutchUI.playerNum)
    if not joypadData then return end
    self:clearJoypadFocus(joypadData)
    self.joypadIndexY = 1
    self.joypadIndex  = 1
    self.joypadButtonsY = {}
    self.joypadButtons  = {}
    if self.closedDoorPanel:isVisible() then
        self:insertNewLineOfButtons(self.openDoorBtn)
        self:setISButtonForX(self.openDoorBtn)
    else
        local boxPerRow    = 2
        local joypadBtns   = {}
        for i, panel in ipairs(self.nestBoxUI) do
            table.insert(joypadBtns, panel)
            if #joypadBtns == boxPerRow then
                self:insertNewListOfButtons(joypadBtns)
                joypadBtns = {}
            end
        end
        if #joypadBtns > 0 then
            self:insertNewListOfButtons(joypadBtns)
        end
        self:setISButtonForX(self.eggHatchDoorBtn)
    end
    self:restoreJoypadFocus(joypadData)
end

function NR_NestPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    if self.closedDoorPanel:isVisible() then
        self:setISButtonForX(self.openDoorBtn)
    else
        self:setISButtonForX(self.eggHatchDoorBtn)
    end
    self:restoreJoypadFocus(joypadData)
end

function NR_NestPanel:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self:clearISButtons()
    self:clearJoypadFocus(joypadData)
end
