-- NR_ColorPicker.lua
-- NeatUI-styled override of ISColorPicker.
-- Only overrides prerender() — color mosaic, selection, joypad all inherited.

require "NeatRocco/NR_Config"

NR_ColorPicker = ISColorPicker:derive("NR_ColorPicker")

function NR_ColorPicker:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        local c = NR_Config.panelBg
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, c, c, c, NR_Config.bgAlpha)
    else
        local c = NR_Config.panelBg
        self:drawRect(0, 0, self.width, self.height, 0.95, c, c, c)
    end
end
