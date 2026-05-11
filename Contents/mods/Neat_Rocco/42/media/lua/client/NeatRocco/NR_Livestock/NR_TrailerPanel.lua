-- NR_TrailerPanel.lua
-- NeatUI-styled override of ISVehicleAnimalUI (Horse trailer / Livestock Trailer).
-- Derives from ISVehicleAnimalUI — all scroll/avatar/resize logic inherited 1:1.

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_BaseCW"
require "NeatRocco/NR_Utils/NR_ScrollingList"

NR_TrailerPanel = ISVehicleAnimalUI:derive("NR_TrailerPanel")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_TrailerPanel:new(vehicle, player)
    local o = ISVehicleAnimalUI.new(self, vehicle, player)
    setmetatable(o, self)
    self.__index = self
    NR_BaseCW.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_TrailerPanel:getWindowTitle()
    return self.title or ""
end

function NR_TrailerPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Trailer.png")
end

function NR_TrailerPanel:titleBarHeight()
    return NR_Config.headerHeight
end

function NR_TrailerPanel:setInfo(text)
    self.infoText = text
end

function NR_TrailerPanel:getInfoText()
    return self.infoText
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_TrailerPanel:createChildren()
    ISVehicleAnimalUI.createChildren(self)

    local bsz = NR_Config.buttonSize

    -- Replace vanilla vscroll render with NeatUI style
    if self.scrollPanel and self.scrollPanel.vscroll then
        NR_ScrollingList.applyNeatStyle(self.scrollPanel.vscroll)
    end

    NR_BaseCW.createHeader(self)

    -- Hide vanilla progressBar (replaced by NR_BaseCW.drawBar in render)
    self.progressBar:setVisible(false)

    -- Hide vanilla addBtn (kept alive — checkCanAddAnimal writes to addBtn.enable)
    self.addBtn:setVisible(false)

    -- NI_SquareButton add — mirrors vanilla addBtn position
    self.neatAddBtn = NI_SquareButton:new(
        self.addBtn:getX(),
        self.addBtn:getY() + math.floor((self.addBtn:getHeight() - bsz) / 2),
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Add.png"),
        self, ISVehicleAnimalUI.onAddAnimal
    )
    self.neatAddBtn:initialise()
    self.neatAddBtn:setActive(true)
    self.neatAddBtn:setActiveColor(0.2, 0.75, 0.2)
    self:addChild(self.neatAddBtn)

    -- Style vanilla resizeWidget with NeatUI icon + minimum size constraint
    -- (resizeWidget2 = bottom bar, not needed)
    if self.resizeWidget2 then
        self.scrollPanel:setHeight(self.scrollPanel:getHeight() + self.resizeWidget2:getHeight())
        self.resizeWidget2:setVisible(false)
    end
    if self.resizeWidget then
        -- scrollPanel (dernier enfant vanilla) dessine par-dessus resizeWidget → le remettre en dernier
        self:removeChild(self.resizeWidget)
        self:addChild(self.resizeWidget)
        local minW = self.avatarWidth * 4 + 100
        local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
        local panelY    = NR_Config.headerHeight + FONT_HGT_SMALL + self.btnHeight + 5
        local scrollMin = self.avatarHeight + 15
        local minH      = panelY + scrollMin + self:resizeWidgetHeight()
        self.resizeWidget.prerender = function(widget)
            local alpha = widget.mouseOver and 0.8 or 0.6
            widget:drawTextureScaledAspect(
                getTexture("media/ui/NeatUI/Resize/ResizeIcon.png"),
                0, 0, widget.width, widget.height, alpha, 1, 1, 1
            )
        end
        self.resizeWidget.resizeFunction = function(target, newW, newH)
            local w = math.max(newW, minW)
            local h = math.max(newH, minH)
            target:setWidth(w)
            target:setHeight(h)
            if target.header then
                target.header:setWidth(w)
                target.header:calculateLayout(w, NR_Config.headerHeight)
            end
        end
    end
end

function NR_TrailerPanel:calculateLayout()
    if self.resizeWidget and self.resizeWidget.resizeFunction then
        self.resizeWidget.resizeFunction(self, 0, 0)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_TrailerPanel:prerender()
    NR_BaseCW.prerenderBody(self)
end

function NR_TrailerPanel:render()
    ISVehicleAnimalUI.render(self)

    -- NeatUI progress bar (replaces vanilla ISProgressBar)
    local barX    = self.progressBar.x
    local barY    = self.progressBar.y
    local barW    = self.progressBar.width
    local barH    = self.progressBar.height
    local progress = math.min(math.max(self.progressBar.progress or 0, 0), 1)

    local valueText = round(self.vehicle:getAnimalTrailerSize() - self.vehicle:getCurrentTotalAnimalSize(), 1) .. ""
    NR_BaseCW.drawBarWithLabel(self, barX, barY, barW, barH, progress, valueText, 0.2, 0.8, 0.3)

    -- Sync neatAddBtn with vanilla addBtn state
    if self.neatAddBtn and self.addBtn then
        self.neatAddBtn.enable = self.addBtn.enable
        self.neatAddBtn:setActive(self.addBtn.enable)
        if self.addBtn.enable then
            self.neatAddBtn:setActiveColor(0.2, 0.75, 0.2)
        end
    end
end
