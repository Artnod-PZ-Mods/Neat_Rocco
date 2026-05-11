-- NR_ResizeWidget.lua
-- Utility for creating NeatUI-styled ISResizeWidget handles.
-- Used by NR_LiteraturePanel, NR_VehicleMechanicsPanel, NR_LivestockZonePanel.

require "ISUI/ISResizeWidget"

NR_ResizeWidget = {}

NR_ResizeWidget.SIZE = 16

local ICON = "media/ui/NeatUI/Resize/ResizeIcon.png"

-- Creates a 16x16 NeatUI resize widget at the bottom-right of panel.
-- resizeFn: function(target, w, h) called on resize.
-- opts: { yonly = bool }  (optional)
function NR_ResizeWidget.create(panel, resizeFn, opts)
    local sz   = NR_ResizeWidget.SIZE
    local rTex = getTexture(ICON)
    local widget = ISResizeWidget:new(panel.width - sz, panel.height - sz, sz, sz, panel)
    widget.anchorRight  = false
    widget.anchorBottom = false
    widget:initialise()
    if opts and opts.yonly then widget.yonly = true end
    widget.prerender = function(w)
        local alpha = w.mouseOver and 0.8 or 0.6
        if rTex then w:drawTextureScaledAspect(rTex, 0, 0, w.width, w.height, alpha, 1, 1, 1) end
    end
    widget.resizeFunction = resizeFn
    ISPanel.addChild(panel, widget)
    widget:setAlwaysOnTop(true)
    return widget
end
