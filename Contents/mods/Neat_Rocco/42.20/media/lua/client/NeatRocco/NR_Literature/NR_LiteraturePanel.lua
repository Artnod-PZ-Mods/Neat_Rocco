-- NR_LiteraturePanel.lua (42.20+ variant)
-- NeatUI replacement for ISLiteratureUI (Apprentissage window).
-- Reuses vanilla list classes (ISLiteratureList/MediaList/GrowingList) and data logic 1:1.
-- 42.20: ISLiteratureList became an ISPanel container holding a filterBox (search) and
-- the actual list; setLists reads listbox1Filter/listbox2Filter/recipeListFilter and
-- recipeListBox, and recipe names are translated at insert time instead of draw time.

require "ISUI/ISLiteratureUI"
require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_ResizeWidget"
require "NeatRocco/NR_Utils/NR_ScrollingList"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_TabBar"

NR_LiteraturePanel = NR_BasePanel:derive("NR_LiteraturePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local ITEM_HGT       = FONT_HGT_SMALL + 6
local FILTER_HGT     = FONT_HGT_SMALL + 4
local RESIZE_H       = 16

-- ----------------------------------------------------------------------------------------------------- --
-- NeatUI item renderers — vanilla logic 1:1, drawRectBorder replaced by NR_Config.separatorColor line
-- ----------------------------------------------------------------------------------------------------- --

local function neatDrawLiteratureItem(self2, y, item)
    local metaKnowledge = getSandboxOptions():getOptionByName("MetaKnowledge"):getValue()
    local showUnknownRecipes
    if metaKnowledge == 1 then showUnknownRecipes = true end
    local r, g, b, a = 0.5, 0.5, 0.5, 1.0
    local itemPadY = (item.height - self2.fontHgt) / 2
    local texture
    local known = false
    if type(item.item) ~= "string" then
        texture = item.item:getNormalTexture()
        local skillBook = SkillBook[item.item:getSkillTrained()]
        if skillBook then
            if (item.item:getNumberOfPages() > 0) and (self2.character:getAlreadyReadPages(item.item:getFullName()) == item.item:getNumberOfPages()) then
                r, g, b = 1.0, 1.0, 1.0; known = true
            elseif item.item:getMaxLevelTrained() <= self2.character:getPerkLevel(skillBook.perk) + 1 then
                r, g, b = 1.0, 1.0, 1.0; known = true
            end
        else
            if self2.character:getAlreadyReadBook():contains(item.item:getFullName()) then
                r, g, b = 1.0, 1.0, 1.0; known = true
            elseif (item.item:getLearnedRecipes() ~= nil) and self2.character:getKnownRecipes():containsAll(item.item:getLearnedRecipes()) then
                r, g, b = 1.0, 1.0, 1.0; known = true
            end
        end
    else
        if self2.character:getKnownRecipes():contains(item.item) then
            if self2.character:isFavouriteRecipe(item.item) then
                r = getCore():getGoodHighlitedColor():getR()
                g = getCore():getGoodHighlitedColor():getG()
                b = getCore():getGoodHighlitedColor():getB()
                known = true
            else
                r, g, b = 1.0, 1.0, 1.0; known = true
            end
        end
        if getSandboxOptions():getOptionByName("SeeNotLearntRecipe"):getValue() == true then showUnknownRecipes = true end
        local icon = getRecipeIcon(item.item)
        if icon then texture = icon end
    end

    local showMeta = metaKnowledge ~= 3
    if showUnknownRecipes then showMeta = true end

    if known == false and not showMeta then return y end
    if item.height == 0 then item.height = self2.itemheight end
    if y + self2:getYScroll() >= self2.height then return y + item.height end
    if y + item.height + self2:getYScroll() <= 0 then return y + item.height end

    local sc = NR_Config.separatorColor
    self2:drawRect(0, y + item.height - 1, self2:getWidth(), 1, sc.a, sc.r, sc.g, sc.b)

    if texture then
        local texHeight = math.min(texture:getHeightOrig(), FONT_HGT_SMALL)
        local texWidth  = texture:getWidthOrig() / (texture:getHeightOrig() / FONT_HGT_SMALL)
        if texWidth <= 32 and texHeight <= 32 then
            self2:drawTextureScaled(texture, 6 + (32 - texWidth) / 2, y + (item.height - texHeight) / 2, texWidth, texHeight, 1, 1, 1, 1)
        else
            self2:drawTextureScaledAspect(texture, 6, y + (item.height - texHeight) / 2, 32, 32, 1, 1, 1, 1)
        end
    end
    -- 42.20: item.text is already translated at insert time (vanilla setLists)
    if known or metaKnowledge == 1 or showUnknownRecipes then
        self2:drawText(item.text, 6 + 32 + 6, y + itemPadY, r, g, b, a, self2.font)
    else
        self2:drawText("???", 6 + 32 + 6, y + itemPadY, r, g, b, a, self2.font)
    end
    return y + item.height
end

local function neatDrawMediaItem(self2, y, item)
    local metaKnowledge = getSandboxOptions():getOptionByName("MetaKnowledge"):getValue()
    if not getZomboidRadio():getRecordedMedia():hasListenedToAll(self2.character, item.item) and metaKnowledge == 3 then
        return y
    end
    if item.height == 0 then item.height = self2.itemheight end
    if y + self2:getYScroll() >= self2.height then return y + item.height end
    if y + item.height + self2:getYScroll() <= 0 then return y + item.height end

    local sc = NR_Config.separatorColor
    self2:drawRect(0, y + item.height - 1, self2:getWidth(), 1, sc.a, sc.r, sc.g, sc.b)

    local texture = self2.scriptItem and self2.scriptItem:getNormalTexture() or nil
    if texture then
        local texWidth  = texture:getWidthOrig()
        local texHeight = texture:getHeightOrig()
        if texWidth <= 32 and texHeight <= 32 then
            self2:drawTexture(texture, 6 + (32 - texWidth) / 2, y + (item.height - texHeight) / 2, 1, 1, 1, 1)
        else
            self2:drawTextureScaledAspect(texture, 6, y + (item.height - texHeight) / 2, 32, 32, 1, 1, 1, 1)
        end
    end

    local r, g, b, a = 0.5, 0.5, 0.5, 1.0
    if getZomboidRadio():getRecordedMedia():hasListenedToAll(self2.character, item.item) then
        r, g, b = 1.0, 1.0, 1.0
    end
    local itemPadY = (item.height - self2.fontHgt) / 2
    if r == 1 or metaKnowledge == 1 then
        self2:drawText(item.text, 6 + 32 + 6, y + itemPadY, r, g, b, a, self2.font)
    else
        self2:drawText("???", 6 + 32 + 6, y + itemPadY, r, g, b, a, self2.font)
    end
    return y + item.height
end

local function neatDrawGrowingItem(self2, y, item)
    local itemPadY = (item.height - self2.fontHgt) / 2
    local prop = farming_vegetableconf.props[item.text]
    if not prop then return y end
    if not prop.seasonRecipe then return y end
    if not self2.character:isRecipeActuallyKnown(prop.seasonRecipe) then return y end
    local texture = getTexture(prop.icon)
    if texture then
        local texWidth  = texture:getWidthOrig()
        local texHeight = texture:getHeightOrig()
        if texWidth <= 32 and texHeight <= 32 then
            self2:drawTexture(texture, 6 + (32 - texWidth) / 2, y + (item.height - texHeight) / 2, 1, 1, 1, 1)
        else
            self2:drawTextureScaledAspect(texture, 6, y + (item.height - texHeight) / 2, 32, 32, 1, 1, 1, 1)
        end
    end

    local text  = getText("Farming_" .. item.text) .. "<LINE>" .. ISFarmingMenu.plantInfo(prop)
    local lines = nil
    if #text:split("<LINE>") > 1 then
        lines = text:split("<LINE>")
        item.height = (#lines * FONT_HGT_SMALL) + (itemPadY / 2)
    end

    if y + self2:getYScroll() >= self2.height then return y + item.height end
    if y + item.height + self2:getYScroll() <= 0 then return y + item.height end

    local sc = NR_Config.separatorColor
    self2:drawRect(0, y + item.height - 1, self2:getWidth(), 1, sc.a, sc.r, sc.g, sc.b)

    local r, g, b, a = 1.0, 1.0, 1.0, 1.0
    if lines then
        for i = 1, #lines do
            self2:drawText(lines[i], 6 + 32 + 6, y + FONT_HGT_SMALL * (i - 1) + (itemPadY / 4), r, g, b, a, self2.font)
        end
    else
        self2:drawText(text, 6 + 32 + 6, y + itemPadY, r, g, b, a, self2.font)
    end
    return y + item.height
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:new(x, y, width, height, character, owner)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character           = character
    o.playerNum           = character:getPlayerNum()
    o.owner               = owner
    o.activeTab           = 1
    o.tabButtons          = {}
    o.listBoxes           = {}
    o.focusables          = {}
    o.tabCount            = 0
    o.agricultureTabIndex = 0

    NR_BasePanel.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:getWindowTitle()
    return getText("IGUI_LiteratureUI_Title")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:createChildren()
    NR_BasePanel.createChildren(self)

    local hh      = NR_Config.headerHeight
    local tabBarH = NR_Config.tabBarHeight

    -- Tab bar (no background)
    self.tabBar = NR_TabBar.create(self, hh)
    self.tabBar:setAnchorRight(true)

    local listY  = hh + tabBarH
    local listH  = self.height - listY - RESIZE_H
    local tabIdx = 0

    -- contentPanel: shown/hidden on tab switch; focusable: receives joypad focus
    local function addTab(name, contentPanel, focusable, texPath)
        tabIdx = tabIdx + 1
        local n   = tabIdx
        local tex = texPath and getTexture(texPath) or getTexture("media/ui/NeatUI/numbers/" .. n .. ".png")
        local btn = NR_TabBar.addButton(self.tabBar, self, n, tex, name, n == 1)
        contentPanel:setVisible(tabIdx == 1)
        self.tabButtons[tabIdx] = btn
        self.listBoxes[tabIdx]  = contentPanel
        self.focusables[tabIdx] = focusable
    end

    -- NeatUI style for an inner ISScrollingListBox (vscroll must already exist)
    local function styleList(list)
        list:setFont(UIFont.Small, 3)
        list.itemheight        = ITEM_HGT
        list.drawBorder        = false
        list.backgroundColor.a = 0
        list.vscroll:setAnchorRight(false)
        list.vscroll:setAnchorBottom(false)
        NR_ScrollingList.applyNeatStyle(list.vscroll)
    end

    -- NeatUI style for the vanilla search box created by ISLiteratureList:createChildren
    local function styleFilterBox(fb)
        local sc = NR_Config.separatorColor
        fb:setHeight(FILTER_HGT)
        fb.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
        fb.borderColor     = { r = sc.r, g = sc.g, b = sc.b, a = sc.a }
    end

    -- Filtered tab (42.20 ISLiteratureList: ISPanel container with filterBox + list).
    -- parent = self so the filterBox onTextChange calls our aliased setLists.
    local function addFilteredTab(name, texPath)
        local container = ISLiteratureList:new(0, listY, self.width, listH, self.character, self)
        container:initialise()
        self:addChild(container)   -- instantiates the container -> creates filterBox + list
        styleFilterBox(container.filterBox)
        container.list:setY(container.filterBox:getBottom())
        container.list:setHeight(listH - container.filterBox:getHeight())
        styleList(container.list)
        container.list.doDrawItem = neatDrawLiteratureItem
        addTab(name, container, container.list, texPath)
        return container
    end

    -- Plain scrolling-list tab (media / growing, unchanged in 42.20)
    local function addListTab(name, listbox, texPath)
        listbox:initialise()
        listbox:setAnchorRight(true)
        listbox:setAnchorBottom(true)
        self:addChild(listbox)
        styleList(listbox)
        addTab(name, listbox, listbox, texPath)
    end

    -- Tab 1: livres de compétences
    local c1 = addFilteredTab(getText("IGUI_LiteratureUI_Skills"), "media/ui/NeatRocco/ICON/Icon_Book.png")
    self.listbox1       = c1.list
    self.listbox1Filter = c1.filterBox

    -- Tab 2: magazines / recettes livres
    local c2 = addFilteredTab(getText("IGUI_LiteratureUI_RecipeBooks"), "media/ui/NeatRocco/ICON/Icon_Magazine.png")
    self.listbox2       = c2.list
    self.listbox2Filter = c2.filterBox

    -- Tab 3: recettes
    local c3 = addFilteredTab(getText("IGUI_LiteratureUI_Recipes"), "media/ui/NeatRocco/ICON/Icon_Recipe.png")
    c3.list:setOnMouseDownFunction(self, self.onRecipeSelected, self)
    self.recipeListBox    = c3.list
    self.recipeListFilter = c3.filterBox

    -- Tabs 4..N: catégories médias (dynamique)
    local categories = getZomboidRadio():getRecordedMedia():getCategories()
    self.listboxMedia = {}
    for i = 1, categories:size() do
        local category = categories:get(i - 1)
        local lb = ISLiteratureMediaList:new(0, listY, self.width, listH, self.character)
        local mediaTex
        if category == "Home-VHS" or category == "Retail-VHS" then
            mediaTex = "media/ui/NeatRocco/ICON/Icon_VHS.png"
        elseif category == "CDs" then
            mediaTex = "media/ui/NeatRocco/ICON/Icon_CD.png"
        end
        addListTab(getText("IGUI_LiteratureUI_RecordedMedia_" .. category), lb, mediaTex)
        lb.doDrawItem = neatDrawMediaItem
        self.listboxMedia[i] = lb
    end

    -- Dernier onglet: agriculture
    local lb5 = ISLiteratureGrowingList:new(0, listY, self.width, listH, self.character)
    addListTab(getText("IGUI_LiteratureUI_Growing"), lb5, "media/ui/NeatRocco/ICON/Icon_Plant.png")
    lb5.doDrawItem = neatDrawGrowingItem
    self.listbox5            = lb5
    self.agricultureTabIndex = tabIdx
    self.tabCount            = tabIdx

    -- Resize handle (pattern NR_Mech : taille fixe 16px, prerender avec alpha hover)
    self.resizeWidget = NR_ResizeWidget.create(self,
        function(_, w, h) self:onResize(w, h) end)

    self:setLists()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Resize
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:onResize(w, h)
    local hh      = NR_Config.headerHeight
    local tabBarH = NR_Config.tabBarHeight
    local listY   = hh + tabBarH
    local listH   = h - listY - RESIZE_H

    self:setWidth(w)
    self:setHeight(h)

    self.tabBar:setWidth(w)
    for _, panel in ipairs(self.listBoxes) do
        panel:setY(listY)
        if panel.filterBox then
            -- filtered container: resize container, search box, then inner list
            panel:setWidth(w)
            panel:setHeight(listH)
            panel.filterBox:setWidth(w)
            panel.list:setY(panel.filterBox:getBottom())
            NR_ScrollingList.setWidth(panel.list, w)
            NR_ScrollingList.setHeight(panel.list, listH - panel.filterBox:getHeight())
        else
            NR_ScrollingList.setWidth(panel, w)
            NR_ScrollingList.setHeight(panel, listH)
        end
    end

    self.header:setWidth(w)
    self.header:calculateLayout(w, hh)

    self.resizeWidget:setX(w - RESIZE_H)
    self.resizeWidget:setY(h - RESIZE_H)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Tab switching
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:switchTab(n)
    self.activeTab = n
    NR_TabBar.switch(self.tabButtons, self.listBoxes, self.tabCount, n)
    local jd = getJoypadData(self.playerNum)
    if jd then
        jd.focus = self.focusables[n]
        updateJoypadFocus(jd)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Data — logique vanilla préservée 1:1 (42.20: lit listbox1Filter/listbox2Filter/recipeListFilter)
-- ----------------------------------------------------------------------------------------------------- --

NR_LiteraturePanel.setLists      = ISLiteratureUI.setLists
NR_LiteraturePanel.setMediaLists = ISLiteratureUI.setMediaLists

function NR_LiteraturePanel:onRecipeSelected(recipe)
    local showMeta       = getSandboxOptions():getOptionByName("MetaKnowledge"):getValue() ~= 3
    local showAllRecipes = getSandboxOptions():getOptionByName("SeeNotLearntRecipe"):getValue() == true and showMeta
    local actuallyKnown  = self.character:isRecipeActuallyKnown(recipe)
    local craftRecipe    = getScriptManager():getCraftRecipe(recipe)
    if not craftRecipe then craftRecipe = getScriptManager():getBuildableRecipe(recipe) end
    local showCraftRecipe = (craftRecipe and actuallyKnown) or showAllRecipes

    if craftRecipe and showCraftRecipe then
        if craftRecipe:isBuildableRecipe() then
            ISEntityUI.OpenBuildWindow(self.character, nil, "*", false, craftRecipe)
        else
            ISEntityUI.OpenHandcraftWindow(self.character, nil, "*", false, craftRecipe)
        end
        return
    end
    if actuallyKnown and doesSeasonRecipeExist(recipe) then
        self:switchTab(self.agricultureTabIndex)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:prerender()
    NR_BasePanel.prerender(self)
    -- Séparateur sous la barre d'onglets
    local lineY = NR_Config.headerHeight + NR_Config.tabBarHeight - 1
    self:drawRect(0, lineY, self.width, 1, 1, 0, 0, 0)
    -- Auto-fermeture si la fenêtre personnage est détruite (comportement vanilla)
    local infoPanel = getPlayerInfoPanel(self.playerNum)
    if not infoPanel or (self.owner ~= infoPanel.charScreen) then
        self:removeFromUIManager()
    end
end

function NR_LiteraturePanel:render()
    ISPanelJoypad.render(self)
    self:drawTabTooltips(self.tabButtons, self.tabCount)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:close()
    self:setLists()
    self:removeFromUIManager()
    -- Clear the singleton reference on ISCharacterScreen so that toggling
    -- useLiterature off lets the vanilla onShowLiterature build a fresh ISLiteratureUI.
    if self.owner and self.owner.literatureUI == self then
        self.owner.literatureUI = nil
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_LiteraturePanel:onGainJoypadFocus(joypadData)
    NR_BasePanel.onGainJoypadFocus(self, joypadData)
    local active = self.focusables[self.activeTab]
    if active then
        joypadData.focus = active
        updateJoypadFocus(joypadData)
    end
end

function NR_LiteraturePanel:onJoypadDown_Descendant(descendant, button, joypadData)
    if button == Joypad.BButton then
        self:close()
        if self.owner then setJoypadFocus(self.playerNum, self.owner) end
        return
    end
    if (button == Joypad.LBumper or button == Joypad.RBumper) and self.tabCount >= 2 then
        local n = self.activeTab
        if button == Joypad.LBumper then
            n = n == 1 and self.tabCount or n - 1
        else
            n = n == self.tabCount and 1 or n + 1
        end
        getSoundManager():playUISound("UIActivateTab")
        self:switchTab(n)
        return
    end
    ISPanelJoypad.onJoypadDown_Descendant(self, descendant, button, joypadData)
end
