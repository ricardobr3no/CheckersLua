-- Resolução virtual: o jogo renderiza num espaço fixo e escala/centraliza
-- para caber na janela, mantendo o layout alinhado em qualquer tamanho de tela.
local View = {}

local virtualW, virtualH = 650, 560
local scale, offsetX, offsetY = 1, 0, 0

function View.init(w, h)
    virtualW, virtualH = w, h
    View.refresh()
end

-- Recalcula escala/offset a partir do tamanho real da janela.
-- Chamado a cada frame (independe do callback de resize).
function View.refresh()
    local screenW, screenH = love.graphics.getDimensions()
    if screenW <= 0 or screenH <= 0 then return end
    scale = math.min(screenW / virtualW, screenH / virtualH)
    offsetX = math.floor((screenW - virtualW * scale) / 2)
    offsetY = math.floor((screenH - virtualH * scale) / 2)
end

-- Chamado no love.resize (mantido para compatibilidade)
function View.resize(screenW, screenH)
    View.refresh()
end

function View.getScale()
    View.refresh()
    return scale
end

function View.getOffset()
    View.refresh()
    return offsetX, offsetY
end

function View.toVirtual(x, y)
    View.refresh()
    return (x - offsetX) / scale, (y - offsetY) / scale
end

function View.apply()
    View.refresh()
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)
end

function View.release()
    love.graphics.pop()
end

return View
