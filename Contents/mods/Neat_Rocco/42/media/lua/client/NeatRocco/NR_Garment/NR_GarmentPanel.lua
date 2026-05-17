-- NR_GarmentPanel.lua
-- NeatUI replacement panel for ISGarmentUI.
-- Derives from ISGarmentUI so any mod patching ISGarmentUI (doContextMenu, doPatch...)
-- runs automatically (e.g. AutoTailoring's "Auto Sewing" menu entry).
-- Displays clothing coverage, protection values, damage state, and bottom condition bars.

require "ISUI/ISGarmentUI"
require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_GarmentPanel = ISGarmentUI:derive("NR_GarmentPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- Texture loading (same mapping as ISGarmentUI)
-- ----------------------------------------------------------------------------------------------------- --

local TEXTURE_MAP = {
    Hand_L     = { tex = "_left-hand",      ovr = "_left_hand"       },
    Hand_R     = { tex = "_right-hand",     ovr = "_right_hand"      },
    ForeArm_L  = { tex = "_lower-left-arm", ovr = "_lower_left_arm"  },
    ForeArm_R  = { tex = "_lower-right-arm",ovr = "_lower_right_arm" },
    UpperArm_L = { tex = "_upper-left-arm", ovr = "_upper_left_arm"  },
    UpperArm_R = { tex = "_upper-right-arm",ovr = "_upper_right_arm" },
    Torso_Upper= { tex = "_chest",          ovr = "_chest"           },
    Torso_Lower= { tex = "_abdomen",        ovr = "_abdomen"         },
    Back       = { tex = "_abdomen",        ovr = "_abdomen"         },
    Head       = { tex = "_head",           ovr = "_head"            },
    Neck       = { tex = "_neck",           ovr = "_neck"            },
    Groin      = { tex = "_groin",          ovr = "_groin"           },
    UpperLeg_L = { tex = "_left-thigh",     ovr = "_left_thigh"      },
    UpperLeg_R = { tex = "_right-thigh",    ovr = "_right_thigh"     },
    LowerLeg_L = { tex = "_left-calf",      ovr = "_left_calf"       },
    LowerLeg_R = { tex = "_right-calf",     ovr = "_right_calf"      },
    Foot_L     = { tex = "_left-foot",      ovr = "_left_foot"       },
    Foot_R     = { tex = "_right-foot",     ovr = "_right_foot"      },
}

local function loadTextures(sex)
    local t = {}
    for partKey, info in pairs(TEXTURE_MAP) do
        local base  = "media/ui/BodyParts/bps_" .. sex .. info.tex .. ".png"
        local pfx   = "media/ui/BodyParts/overlays/" .. sex .. "_clothing_overlays_"
        t[partKey] = {
            texture = getTexture(base),
            hole    = getTexture(pfx .. "holes"   .. info.ovr .. ".png"),
            blood   = getTexture(pfx .. "blood"   .. info.ovr .. ".png"),
            patch   = getTexture(pfx .. "patches" .. info.ovr .. ".png"),
        }
    end
    return t
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

-- :new is intentionally NOT overridden. NR_MakePatch redirects ISGarmentUI:new ->
-- NR_GarmentPanel via vanilla ISGarmentUI.new, which creates the instance with
-- vanilla width=460. Our :initialise then runs _nrSetupLayout to compute the actual
-- NeatUI width from texture/text content and store all NR-specific props.

local function _nrSetupLayout(self)
    local character = self.chr
    local clothing  = self.clothing
    local playerNum = character:getPlayerNum()
    local pad = NR_Config.padding
    local tm  = getTextManager()
    local sex = character:isFemale() and "female" or "male"

    -- Load body part textures
    local textures = loadTextures(sex)

    -- Build covered parts list (only parts that have a texture)
    local parts = {}
    local minX, minY, maxX, maxY = 1000, 1000, -1000, -1000
    for i = 0, clothing:getCoveredParts():size() - 1 do
        local part    = clothing:getCoveredParts():get(i)
        local partKey = part:toString()
        local entry   = textures[partKey]
        if entry and entry.texture then
            table.insert(parts, part)
            local tex = entry.texture
            minX = math.min(minX, tex:getOffsetX())
            minY = math.min(minY, tex:getOffsetY())
            maxX = math.max(maxX, tex:getOffsetX() + tex:getWidth())
            maxY = math.max(maxY, tex:getOffsetY() + tex:getHeight())
        end
    end

    -- Image area dimensions (from sprite offset bounds)
    local imgW = (maxX > -1000) and (maxX - minX) or 0
    local imgH = (maxY > -1000) and (maxY - minY) or 0

    -- Text columns start after the image area
    local listX    = (imgW > 0) and (pad + imgW + pad) or pad
    local partW    = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_BodyPart"))
    for _, part in ipairs(parts) do
        partW = math.max(partW, tm:MeasureStringX(UIFont.Small, part:getDisplayName()))
    end
    local biteW    = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Bite"))
    local scratchW = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Scratch"))
    local bulletW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Bullet"))

    local biteX    = listX + partW + pad
    local scratchX = biteX + biteW + pad
    local bulletX  = scratchX + scratchW + pad

    -- Bottom bar widths: each bar is at least as wide as its label
    local condW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_invpanel_Condition"))
    local bloodW = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_GlbBlood"))
    local dirtW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_GlbDirt"))
    local minBarW = 60
    local barW1 = math.max(condW,  minBarW)
    local barW2 = math.max(bloodW, minBarW)
    local barW3 = math.max(dirtW,  minBarW)
    local bar1X = pad
    local bar2X = bar1X + barW1 + pad
    local bar3X = bar2X + barW2 + pad
    local minBarsW = bar3X + barW3 + pad

    local width = math.max(bulletX + bulletW + pad, minBarsW, 300)

    -- Resize panel to fit NeatUI content and recenter on player screen.
    self:setWidth(width)
    self:setHeight(NR_Config.headerHeight + 100)
    self:setX(getPlayerScreenLeft(playerNum) + math.floor((getPlayerScreenWidth(playerNum) - width) / 2))

    -- Store layout / data props
    self.character = character    -- alias for code using `character`
    self.playerNum = playerNum
    self.barW1 = barW1; self.bar1X = bar1X
    self.barW2 = barW2; self.bar2X = bar2X
    self.barW3 = barW3; self.bar3X = bar3X
    self.textures = textures
    self.parts    = parts
    self.listX    = listX
    self.biteX    = biteX
    self.scratchX = scratchX
    self.bulletX  = bulletX
    self.imgMinX  = (minX < 1000) and minX or 0
    self.imgMinY  = (minY < 1000) and minY or 0
    self.imgW     = imgW
    self.imgH     = imgH
    self.rowYPositions    = {}
    self.bodyPartAction   = {}
    self.actionToBodyPart = {}

    NR_BasePanel.initBase(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:getWindowTitle()
    return self.clothing and self.clothing:getDisplayName() or ""
end

function NR_GarmentPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Tailoring.png")
end

-- ----------------------------------------------------------------------------------------------------- --
-- TimedAction callbacks (called via ISGarmentUI.windows[playerNum])
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:setBodyPartAction(bodyPart, args)
    self.bodyPartAction = self.bodyPartAction or {}
    self.bodyPartAction[bodyPart] = args
end

function NR_GarmentPanel:setBodyPartForAction(action, bodyPart)
    self.actionToBodyPart = self.actionToBodyPart or {}
    self.actionToBodyPart[action] = bodyPart
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

-- Bypass ISGarmentUI:initialise (which creates a vanilla listbox we don't use).
-- _nrSetupLayout runs first so self.width / self.parts / self.listX etc. are set
-- before :createChildren is invoked by ISPanelJoypad.initialise.
function NR_GarmentPanel:initialise()
    _nrSetupLayout(self)
    ISPanelJoypad.initialise(self)
end

-- Recopie de NR_BasePanel:createChildren (header NeatUI)
function NR_GarmentPanel:createChildren()
    local hh = NR_Config.headerHeight
    self.header = NR_Header:new(0, 0, self.width, hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(self.width, hh)
    if self.header.width > self.width then
        self:setWidth(self.header.width)
    end
end

-- Recopie de NR_BasePanel:prerender (background NeatUI)
function NR_GarmentPanel:prerender()
    NR_DrawUtils.prerenderPanelBody(self, NR_Config.headerHeight)
end

function NR_GarmentPanel:update()
    if not self.clothing or not self.clothing:isInPlayerInventory() then
        self:close()
        return
    end
    ISPanelJoypad.update(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Context menu — inherited from ISGarmentUI (doContextMenu, doPatch).
-- Mod patches on ISGarmentUI.doContextMenu (e.g. AutoTailoring's "Auto Sewing" entry) apply automatically.
-- ----------------------------------------------------------------------------------------------------- --

-- ----------------------------------------------------------------------------------------------------- --
-- Mouse
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:onRightMouseUp(_, y)
    for _, row in ipairs(self.rowYPositions) do
        if y >= row.y and y < row.y + row.h then
            self:doContextMenu(row.part, getMouseX(), getMouseY())
            return true
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:render()
    local clothing = self.clothing
    if not clothing then return end
    ISPanelJoypad.render(self)

    local pad  = NR_Config.padding
    local lh   = NR_Config.smallLineHeight
    local barH = NR_Config.barHeight
    local hh   = NR_Config.headerHeight
    local mx   = self:getMouseX()
    local my   = self:getMouseY()
    local mouseInPanel = mx >= 0 and mx < self.width and my >= 0 and my < self.height

    self.rowYPositions = {}

    local curY = hh + pad

    -- "Can't be repaired" notice
    if not clothing:getFabricType() then
        self:drawText(getText("IGUI_garment_CantRepair"), self.listX, curY, 1, 0.3, 0.3, 1, UIFont.Small)
        curY = curY + lh + pad / 2
    end

    -- Column headers
    self:drawText(getText("IGUI_garment_BodyPart"), self.listX,    curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Bite"),      self.biteX,    curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Scratch"),   self.scratchX, curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Bullet"),    self.bulletX,  curY, 1, 1, 1, 0.6, UIFont.Small)
    curY = curY + lh + 2

    -- Separator under headers
    self:drawRect(self.listX, curY, self.width - self.listX - pad, 1, 0.7, 0.5, 0.5, 0.5)
    curY = curY + pad / 2 + 1

    local bad  = getCore():getBadHighlitedColor()
    local good = getCore():getGoodHighlitedColor()
    local br, bg_, bb = bad:getR(), bad:getG(), bad:getB()
    local gr, gg, gb  = good:getR(), good:getG(), good:getB()

    for _, part in ipairs(self.parts) do
        local rowStartY = curY
        local rowH      = lh

        -- Pre-calculate row height for hover
        if clothing:getVisual():getHole(part) > 0            then rowH = rowH + lh end
        if clothing:getBloodlevelForPart(part) > 0           then rowH = rowH + lh end
        if clothing:getPatchType(part)                        then rowH = rowH + lh end
        local bpa = self.bodyPartAction and self.bodyPartAction[part]
        if not bpa then
            local aq = ISTimedActionQueue.getTimedActionQueue(self.character)
            if aq and aq.queue and aq.queue[1] and self.actionToBodyPart and self.actionToBodyPart[aq.queue[1]] == part then
                bpa = { delta = aq.queue[1]:getJobDelta(), jobType = aq.queue[1].jobType }
            end
        end
        if bpa then rowH = rowH + barH end

        -- Hover highlight
        if mouseInPanel and my >= rowStartY and my < rowStartY + rowH then
            self:drawRect(self.listX, rowStartY, self.width - self.listX, rowH, 0.1, 1, 1, 1)
        end

        -- Protection values
        self:drawText(part:getDisplayName(),                              self.listX,    curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, true,  false) .. "%", self.biteX,    curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, false, false) .. "%", self.scratchX, curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, false, true)  .. "%", self.bulletX,  curY, 1, 1, 1, 1, UIFont.Small)
        curY = curY + lh

        -- Hole
        if clothing:getVisual():getHole(part) > 0 then
            self:drawText(getText("IGUI_garment_Hole"), self.listX + 8, curY, br, bg_, bb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Blood
        local bloodLevel = clothing:getBloodlevelForPart(part)
        if bloodLevel > 0 then
            self:drawText(getText("IGUI_garment_Blood") .. round(bloodLevel * 100, 0) .. "%", self.listX + 8, curY, br, bg_, bb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Patch
        local patch = clothing:getPatchType(part)
        if patch then
            self:drawText("- " .. getText("IGUI_TypeOfPatch", patch:getFabricTypeName()), self.listX + 8, curY, gr, gg, gb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Progress bar (active sewing action on this part)
        if bpa then
            NR_DrawBar.drawBar(self, self.listX, curY, self.width - self.listX - pad, barH, bpa.delta or 0, 0.2, 0.8, 0.4)
            if bpa.jobType then
                self:drawText(bpa.jobType, self.listX + pad, curY + math.floor((barH - FONT_HGT_SMALL) / 2), 1, 1, 1, 1, UIFont.Small)
            end
            curY = curY + barH
        end

        table.insert(self.rowYPositions, { part = part, y = rowStartY, h = rowH })
    end

    -- Clothing silhouette (drawn at left, all parts stacked at same anchor)
    if self.imgW > 0 then
        local texAnchorX = pad - self.imgMinX
        local texAnchorY = hh + pad - self.imgMinY
        for _, part in ipairs(self.parts) do
            local entry = self.textures[part:toString()]
            if entry then
                if entry.texture then
                    self:drawTexture(entry.texture, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
                if clothing:getVisual():getHole(part) > 0 and entry.hole then
                    self:drawTexture(entry.hole, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
                if clothing:getBloodlevelForPart(part) > 0 and entry.blood then
                    self:drawTexture(entry.blood, texAnchorX, texAnchorY, clothing:getBloodlevelForPart(part) + 0.1, 1, 1, 1)
                end
                if clothing:getPatchType(part) and entry.patch then
                    self:drawTexture(entry.patch, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
            end
        end
    end

    -- Separator before bottom bars
    curY = curY + 1
    NR_DrawUtils.drawSeparator(self, curY)
    curY = curY + pad

    -- Bottom 3 bars: Condition / Bloodiness / Dirtiness (widths pre-calculated in new())
    self:drawText(getText("IGUI_invpanel_Condition"), self.bar1X, curY, 1, 1, 1, 0.8, UIFont.Small)
    self:drawText(getText("IGUI_garment_GlbBlood"),   self.bar2X, curY, 1, 1, 1, 0.8, UIFont.Small)
    self:drawText(getText("IGUI_garment_GlbDirt"),    self.bar3X, curY, 1, 1, 1, 0.8, UIFont.Small)
    curY = curY + lh + 2

    local condPct  = clothing:getCondition() / clothing:getConditionMax()
    local bloodPct = clothing:getBloodlevel() / 100
    local dirtPct  = clothing:getDirtiness()  / 100
    local cr, cg, cb = NR_DrawBar.getBarColor(condPct)
    NR_DrawBar.drawBarWithLabel(self, self.bar1X, curY, self.barW1, barH, condPct,  math.floor(condPct  * 100) .. "%", cr,  cg,   cb)
    NR_DrawBar.drawBarWithLabel(self, self.bar2X, curY, self.barW2, barH, bloodPct, math.floor(bloodPct * 100) .. "%", 0.8, 0.1,  0.1)
    NR_DrawBar.drawBarWithLabel(self, self.bar3X, curY, self.barW3, barH, dirtPct,  math.floor(dirtPct  * 100) .. "%", 0.7, 0.45, 0.1)

    curY = curY + barH + pad
    self:setHeight(curY)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:close()
    local pn = self.playerNum
    if ISGarmentUI.windows[pn] == self then
        ISGarmentUI.windows[pn] = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if JoypadState.players[pn + 1] then
        if isJoypadFocusOnElementOrDescendant(pn, self) then
            setJoypadFocus(pn, nil)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad / keyboard (recopie de NR_BasePanel — overrides ISGarmentUI joypad handling)
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:onGainJoypadFocus(_) self.drawJoypadFocus = true  end
function NR_GarmentPanel:onLoseJoypadFocus(_) self.drawJoypadFocus = false end

function NR_GarmentPanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then self:close() ; return end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function NR_GarmentPanel:isKeyConsumed(_) return false end

function NR_GarmentPanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() ; return true end
end
