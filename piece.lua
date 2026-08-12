local Piece = {}
Piece.__index = Piece

Piece.crownImage = nil

local function damp(current, target, rate, dt)
    return current + (target - current) * (1 - math.exp(-rate * dt))
end

function Piece.loadAssets()
    local success, img = pcall(love.graphics.newImage, "assets/crown.png")
    if success then
        Piece.crownImage = img
    else
        print("Aviso: 'crown.png' não encontrada. Usando círculo provisório.")
    end
end

function Piece.new(player, row, col)
    local self = setmetatable({}, Piece)
    self.player = player
    self.row = row
    self.col = col
    self.isKing = false
    self.scale = 1
    self.alpha = 1
    self.popT = nil
    self.displayX = (col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
    self.displayY = (row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
    return self
end

function Piece:copy()
    local copy = Piece.new(self.player, self.row, self.col)
    copy.isKing = self.isKing
    return copy
end

function Piece:getDirections()
    local h = { 1, -1 }
    local v = { self.player == 1 and 1 or -1 }

    if self.isKing then
        v = { 1, -1 }
    end

    local dirs = {}
    for _, dv in ipairs(v) do
        for _, dh in ipairs(h) do
            table.insert(dirs, { dv, dh })
        end
    end
    return dirs
end

function Piece:promote()
    self.isKing = true
    self:pop()
    print("Peça promovida a Dama!")
end

function Piece:pop()
    self.popT = 0
end

function Piece:update(dt)
    local targetX = (self.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
    local targetY = (self.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
    self.displayX = damp(self.displayX, targetX, 10, dt)
    self.displayY = damp(self.displayY, targetY, 10, dt)

    if self.popT ~= nil then
        self.popT = math.min(1, self.popT + dt * 3.2)
        self.scale = 1 + 0.35 * math.sin(self.popT * math.pi)
        if self.popT >= 1 then
            self.popT = nil
            self.scale = 1
        end
    end
end

local function pieceColors(player)
    if player == 1 then
        return {
            shadow = { 0, 0, 0 },
            rim    = { 0.42, 0.08, 0.06 },
            body   = { 0.78, 0.18, 0.14 },
            top    = { 0.98, 0.36, 0.30 },
            shine  = { 1.0, 0.62, 0.55 },
            band   = { 0.55, 0.11, 0.09 },
        }
    else
        return {
            shadow = { 0, 0, 0 },
            rim    = { 0.35, 0.33, 0.28 },
            body   = { 0.90, 0.88, 0.82 },
            top    = { 1.0, 0.99, 0.97 },
            shine  = { 1, 1, 1 },
            band   = { 0.55, 0.53, 0.47 },
        }
    end
end

-- Desenha uma peça genérica em (x, y) com raio r e alfa a (usada p/ peças vivas e "ghosts")
local function drawPieceBody(x, y, r, player, isKing, alpha, glow)
    local c = pieceColors(player)

    -- glow (peça selecionada / destaque)
    if glow then
        love.graphics.setColor(1, 0.9, 0.3, 0.35 * alpha)
        love.graphics.circle("fill", x, y, r * 1.18)
    end

    -- sombra
    love.graphics.setColor(c.shadow[1], c.shadow[2], c.shadow[3], 0.35 * alpha)
    love.graphics.circle("fill", x + r * 0.08, y + r * 0.12, r)

    -- aro externo
    love.graphics.setColor(c.rim[1], c.rim[2], c.rim[3], alpha)
    love.graphics.circle("fill", x, y, r)

    -- corpo
    love.graphics.setColor(c.body[1], c.body[2], c.body[3], alpha)
    love.graphics.circle("fill", x, y - r * 0.03, r * 0.94)

    -- degradê: anéis internos mais claros
    love.graphics.setColor(c.top[1], c.top[2], c.top[3], alpha)
    love.graphics.circle("fill", x, y - r * 0.06, r * 0.76)

    -- bandas decorativas da dama
    if isKing then
        love.graphics.setColor(c.band[1], c.band[2], c.band[3], alpha)
        love.graphics.circle("line", x, y, r * 0.66)
        love.graphics.setLineWidth(r * 0.08)
        love.graphics.circle("line", x, y, r * 0.55)
        love.graphics.setLineWidth(1)
    end

    -- brilho (highlight)
    love.graphics.setColor(c.shine[1], c.shine[2], c.shine[3], alpha)
    love.graphics.circle("fill", x - r * 0.28, y - r * 0.38, r * 0.22)
    love.graphics.circle("fill", x - r * 0.42, y - r * 0.22, r * 0.10)
end

function Piece:draw(x, y, squareSize, opts)
    opts = opts or {}
    local r = squareSize * 0.42 * self.scale
    local alpha = self.alpha * (opts.alpha or 1)

    -- hover: levemente maior
    if opts.hovered then
        r = r * 1.08
    end

    drawPieceBody(x, y, r, self.player, self.isKing, alpha, opts.glow)

    if self.isKing and Piece.crownImage then
        love.graphics.setColor(1, 1, 1, alpha)
        local imgW = Piece.crownImage:getWidth()
        local imgH = Piece.crownImage:getHeight()
        local scale = (r * 1.05) / math.max(imgW, imgH)
        love.graphics.draw(Piece.crownImage, x, y, 0, scale, scale, imgW / 2, imgH / 2)
    end
end

-- Ghost de peça capturada (some suavemente)
function Piece.drawGhost(x, y, r, player, isKing, alpha)
    drawPieceBody(x, y, r, player, isKing, math.max(0, math.min(1, alpha)))
end

return Piece
