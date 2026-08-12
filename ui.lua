UI = {}
UI.buttons = {}

local function drawRoundedRect(x, y, w, h, r)
    love.graphics.rectangle("fill", x, y, w, h, r, r)
end

function UI.newButton(label, x, y, width, height, onClick)
    local button = {
        label = label,
        x = x,
        y = y,
        width = width,
        height = height,
        isHovered = false,
        onClick = onClick
    }
    table.insert(UI.buttons, button)
end

function UI.clear()
    UI.buttons = {}
end

function UI.update(dt)
    local mx, my = love.mouse.getPosition()
    for _, button in ipairs(UI.buttons) do
        button.isHovered = mx > button.x and mx < button.x + button.width and my > button.y and
        my < button.y + button.height
    end
end

function UI.draw()
    local font = love.graphics.getFont()
    local pressed = love.mouse.isDown(1)

    for _, btn in ipairs(UI.buttons) do
        local x, y, w, h = btn.x, btn.y, btn.width, btn.height
        local r = h * 0.28
        local isPressed = pressed and btn.isHovered

        if isPressed then
            y = y + 2
        end

        -- sombra
        love.graphics.setColor(0, 0, 0, 0.4)
        drawRoundedRect(x + 2, y + 3, w, h, r)

        -- corpo com gradiente (duas camadas)
        if btn.isHovered then
            love.graphics.setColor(0.26, 0.32, 0.46)
        else
            love.graphics.setColor(0.16, 0.20, 0.30)
        end
        if isPressed then
            love.graphics.setColor(0.11, 0.14, 0.22)
        end
        drawRoundedRect(x, y, w, h, r)

        love.graphics.setColor(1, 1, 1, btn.isHovered and 0.18 or 0.08)
        drawRoundedRect(x + 2, y + 2, w - 4, h / 2 - 2, r * 0.8)

        -- borda
        love.graphics.setColor(0.62, 0.70, 0.9, btn.isHovered and 0.9 or 0.45)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, w, h, r, r)

        -- texto
        love.graphics.setColor(btn.isHovered and 1 or 0.88, btn.isHovered and 0.92 or 0.88, btn.isHovered and 0.75 or 0.88)
        local textW = font:getWidth(btn.label)
        local textH = font:getHeight()
        love.graphics.print(btn.label, x + w / 2 - textW / 2, y + h / 2 - textH / 2)
    end
end

function UI.mousepressed(x, y, button)
    if button == 1 then
        for _, btn in ipairs(UI.buttons) do
            if btn.isHovered and btn.onClick then
                btn.onClick()
            end
        end
    end
end

return UI
