-- NR_AnimalUI.lua
-- NeatUI-styled override of ISAnimalUI.
-- Replaces the vanilla ISCollapsableWindowJoypad title bar with NR_Header.
-- Does NOT call ISCollapsableWindowJoypad.prerender() to avoid the stencilRect clip.

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_BaseCW"

NR_AnimalUI = ISAnimalUI:derive("NR_AnimalUI")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalUI:new(x, y, animal, player)
    local tm  = getTextManager()
    local pad = NR_Config.padding

    local avatarDef    = AnimalAvatarDefinition[animal:getAnimalType()]
    local avatarWidth  = (avatarDef and avatarDef.avatarWidth)  or 128
    local avatarHeight = (avatarDef and avatarDef.avatarHeight) or 128

    -- Always-visible left-column labels (right-aligned to xOffset).
    -- Conditional/cheat-only keys excluded: getText() returns the key itself when untranslated.
    local function lw(k) return tm:MeasureStringX(UIFont.Small, getText(k)) end
    local textWid = math.max(
        lw("IGUI_AnimalType"),         lw("IGUI_AnimalBreed"),
        lw("UI_characreation_gender"),  lw("IGUI_char_Age"),
        lw("IGUI_XP_Health"),           lw("IGUI_Animal_Appearance"),
        lw("IGUI_Animal_Stress"),       lw("IGUI_Animal_ZoneName")
    )

    -- Full NR_Config layout — no vanilla pixel constants
    -- avatarX = pad, gap avatar→labels = pad*4
    -- Value column width is computed dynamically in render(); initial width is minimal
    local avatarX = pad
    local xOffset = avatarX + avatarWidth + pad * 4 + textWid
    local width   = xOffset + pad
    local height  = NR_Config.headerHeight + pad + avatarHeight + pad * 2

    local o = ISAnimalUI.new(self, x, y, width, height, animal, player)
    setmetatable(o, self)
    self.__index = self
    o._nrTextWid = textWid
    NR_BaseCW.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalUI:getWindowTitle()
    return getText("ContextMenu_AnimalInfo")
end

function NR_AnimalUI:titleBarHeight()
    return NR_Config.headerHeight
end

function NR_AnimalUI:getInfoText()
    return self.infoText
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalUI:create()
    ISAnimalUI.create(self)

    local pad = NR_Config.padding
    local bsz = NR_Config.buttonSize

    -- Override vanilla layout (avatarX=25, gap=55, avatarY=headerHeight+10) with NR_Config values
    self.avatarX = pad
    self.avatarY = NR_Config.headerHeight + pad
    self.avatarPanel:setX(self.avatarX)
    self.avatarPanel:setY(self.avatarY)
    self.xOffset = self.avatarX + self.avatarPanel.width + pad * 4 + (self._nrTextWid or 0)

    NR_BaseCW.createHeader(self)

    -- NI_SquareButton milk — in content area, repositioned in render()
    self.milkAnimalBtn:setVisible(false)
    self.neatMilkBtn = NI_SquareButton:new(0, 0, bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Milk.png"), self,
        function() self:onMilkAnimal() end)
    self.neatMilkBtn:initialise()
    self.neatMilkBtn:setActive(true)
    self.neatMilkBtn:setVisible(false)
    self:addChild(self.neatMilkBtn)

    -- NI_SquareButton rename — in content area, repositioned in render()
    self.renameBtn:setVisible(false)
    self.neatRenameBtn = NI_SquareButton:new(
        0, 0, bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Rename.png"),
        self,
        function() self:renameAnimal() end
    )
    self.neatRenameBtn:initialise()
    self.neatRenameBtn:setActive(true)
    self:addChild(self.neatRenameBtn)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalUI:prerender()
    -- Validity / distance checks (copied from ISAnimalUI.prerender)
    if not self.animal or (not self.animal:isExistInTheWorld() and not self.animal:getHutch() and not self.animal:getVehicle() and not self.animal:isHeld()) or self.animal:getHealth() <= 0 then
        self:close() ; return
    end
    if not AnimalContextMenu.cheat then
        if self.animal:isExistInTheWorld() and self.animal:getCurrentSquare():DistToProper(self.chr) > ISAnimalUI.maxDist then
            self:close() ; return
        end
        if self.animal:getVehicle() and self.animal:getVehicle():getCurrentSquare():DistToProper(self.chr) > 4 then
            self:close() ; return
        end
        if self.animal:getHutch() and self.animal:getHutch():getSquare():DistToProper(self.chr) > 4 then
            self:close() ; return
        end
    end

    -- Avatar setup (copied from ISAnimalUI.prerender)
    self.avatarPanel:setZoom(self.avatarDefinition.zoom * self.animal:getData():getSize())
    self.avatarPanel:setXOffset(self.avatarDefinition.xoffset * self.animal:getData():getSize())
    self.avatarPanel:setYOffset(self.avatarDefinition.yoffset * self.animal:getData():getSize())
    self:updateAvatar()
    local x, y, w, h = self.avatarX, self.avatarY, self.avatarWidth, self.avatarHeight
    self:drawRectBorder(x - 2, y - 2, w + 4, h + 4, 1, 0.3, 0.3, 0.3)
    self:drawTextureScaled(self.avatarBackgroundTexture, x, y, w, h, 1, 0.4, 0.4, 0.4)

    NR_BaseCW.prerenderBody(self)
end

function NR_AnimalUI:render()
    ISAnimalUI.render(self)
    local bsz = NR_Config.buttonSize
    if self.neatMilkBtn and self.milkAnimalBtn then
        local visible = self.milkAnimalBtn:isVisible()
        self.milkAnimalBtn:setVisible(false)
        self.neatMilkBtn:setVisible(visible)
        if visible then
            self.neatMilkBtn:setX(self.milkAnimalBtn:getX())
            self.neatMilkBtn:setY(self.milkAnimalBtn:getY() + math.floor((self.milkAnimalBtn:getHeight() - bsz) / 2))
            self.neatMilkBtn.enable = self.milkAnimalBtn.enable
            self.neatMilkBtn:setActive(self.milkAnimalBtn.enable)
        end
    end
    local tm  = getTextManager()
    local pad = NR_Config.padding

    -- Rename button: position right of animal name (mirrors ISAnimalUI:render() name x)
    local nameX  = self.avatarPanel.x + self.avatarPanel.width + 30
    local txt    = AnimalContextMenu.cheat and (" (" .. self.animal:getAnimalID() .. ")") or ""
    local nameW  = tm:MeasureStringX(UIFont.Medium, self.animalName .. txt)
    local btnX   = nameX + nameW + pad
    local btnY   = self.avatarPanel.y + math.floor((tm:getFontHeight(UIFont.Medium) - bsz) / 2)
    if self.neatRenameBtn then
        self.neatRenameBtn:setX(btnX)
        self.neatRenameBtn:setY(btnY)
        self.neatRenameBtn:setVisible(true)
    end

    -- Dynamic width: measure actual value strings + rename button, set once
    local function vw(s) return tm:MeasureStringX(UIFont.Small, s) end
    local valueW = math.max(
        vw(getText("IGUI_AnimalType_"  .. self.animal:getAnimalType())),
        vw(getText("IGUI_Breed_"       .. self.animal:getData():getBreed():getName())),
        vw(self.animal:getAppearanceText(AnimalContextMenu.cheat)),
        vw(self.animal:getAgeText(AnimalContextMenu.cheat, self.skillLvl)),
        vw(self.animal:getHealthText(AnimalContextMenu.cheat, self.skillLvl)),
        vw(self.animal:getStressTxt(AnimalContextMenu.cheat, self.skillLvl))
    )
    if self.animal:getDZone() then
        valueW = math.max(valueW, vw(self.animal:getDZone():getName()))
    end
    -- xOffset+10: vanilla value column start baked into ISAnimalUI:render()
    local requiredW = math.max(
        self.xOffset + 10 + valueW + pad,
        btnX + bsz + pad
    )
    if requiredW ~= self.width then
        self:setWidth(requiredW)
        self.header:calculateLayout(requiredW, NR_Config.headerHeight)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Actions
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalUI:renameAnimal()
    local modal = ISTextBox:new(0, 0, 280, 180, getText("ContextMenu_RenameBag"), self.animalName, self, ISAnimalUI.onRenameAnimalClick)
    modal:initialise()
    modal:addToUIManager()
    modal.maxChars = 30
    if getJoypadFocus(self.playerNum) then
        modal:centerOnScreen(self.playerNum)
        modal.prevFocus = getJoypadFocus(self.playerNum)
        setJoypadFocus(self.playerNum, modal)
    end
end
