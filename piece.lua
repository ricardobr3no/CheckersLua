local Piece = {}
Piece.__index = Piece

-- Variável da classe para guardar a imagem (carregada apenas uma vez)
Piece.crownImage = nil

-- Função para carregar a imagem (deve ser chamada no início do jogo)
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
    self.player = player -- 1 ou 2
    self.row = row
    self.col = col
    self.isKing = false -- Começa como peça normal
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
    print("Peça promovida a Dama!")
end

-- NOVO: A própria peça sabe como desenhar-se
function Piece:draw(centerX, centerY, squareSize)
    -- circulo externo
    love.graphics.setColor(0.7, 0.7, 0.3) -- cinza
    love.graphics.circle("fill", centerX, centerY, squareSize * 0.45)

    -- Cor do corpo da peça
    if self.player == 1 then
        love.graphics.setColor(1, 0, 0) -- Vermelho
    else
        love.graphics.setColor(1, 1, 1) -- Branco
    end

    love.graphics.circle("fill", centerX, centerY, squareSize * 0.4)

    -- Lógica da Dama (King)
    if self.isKing then
        if Piece.crownImage then
            love.graphics.setColor(1, 1, 1) -- Reset para cor original da imagem

            local imgWidth = Piece.crownImage:getWidth()
            local imgHeight = Piece.crownImage:getHeight()
            local scale = (squareSize * 0.6) / math.max(imgWidth, imgHeight)

            local originX = imgWidth / 2
            local originY = imgHeight / 2

            love.graphics.draw(Piece.crownImage, centerX, centerY, 0, scale, scale, originX, originY)
        else
            love.graphics.setColor(1, 0.8, 0)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", centerX, centerY, squareSize * 0.25)
        end
    end
end

return Piece
