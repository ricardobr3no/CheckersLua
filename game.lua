local Config            = require("config")
local Board             = require("board")
local Piece             = require("piece")
local UI                = require("ui")
local AI                = require("ai")

local Game              = {}

-- ─── Estado interno ───────────────────────────────────────────────────────────
local gameState         = "MENU"
local gameMode          = nil
local winner            = nil
local aiDelay           = 0
local aiThinking        = false

local selectedPiece     = nil
local validMoves        = {}
local mandatoryPieces   = {}
local multiCapturePiece = nil

local fontTitle  = nil
local fontBig    = nil
local fontMedium = nil
local fontSmall  = nil

local OX = Config.BOARD_OFFSET_X
local OY = Config.BOARD_OFFSET_Y

-- ─── Setup ────────────────────────────────────────────────────────────────────
function Game.load()
    love.window.setTitle("CheckersLua")
    love.window.setMode(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    love.graphics.setDefaultFilter("nearest", "nearest", 0)

    fontTitle  = love.graphics.newFont(42)
    fontBig    = love.graphics.newFont(26)
    fontMedium = love.graphics.newFont(18)
    fontSmall  = love.graphics.newFont(13)
    love.graphics.setFont(fontMedium)

    Piece.loadAssets()
    MoveSound    = love.audio.newSource("assets/sound_board_move_asset.wav", "static")
    CaptureSound = love.audio.newSource("assets/sound_board_jump_asset.wav", "static")
    Game.showMenu()
end

-- ─── Transições de estado ─────────────────────────────────────────────────────
function Game.showMenu()
    gameState = "MENU"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Humano vs Humano", cx - 110, 170, 220, 54, function() Game.startPlaying(Config.MODES.PVP) end)
    UI.newButton("Humano vs Computador", cx - 110, 240, 220, 54, function() Game.startPlaying(Config.MODES.PVC) end)
    UI.newButton("Créditos", cx - 110, 310, 220, 54, function() Game.showCredits() end)
    UI.newButton("Sair", cx - 110, 380, 220, 54, function() love.event.quit() end)
end

function Game.showCredits()
    gameState = "CREDITS"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Voltar", cx - 110, 470, 220, 54, function() Game.showMenu() end)
end

function Game.startPlaying(mode)
    gameState         = "PLAYING"
    gameMode          = mode
    winner            = nil
    selectedPiece     = nil
    validMoves        = {}
    mandatoryPieces   = {}
    multiCapturePiece = nil
    aiDelay           = 0
    aiThinking        = false
    Board:restart()

    UI.clear()
    UI.newButton("Menu", 548, 18, 92, 40, function() Game.showMenu() end)
    UI.newButton("Reiniciar", 548, 70, 92, 40, function() Game.startPlaying(mode) end)
end

-- ─── Input ────────────────────────────────────────────────────────────────────
local function canStillCapture(row, col)
    local moves = Board:getValidMoves(row, col, true)
    for _, m in ipairs(moves) do
        if m.isCapture then return true end
    end
    return false
end

local function endTurn()
    multiCapturePiece = nil
    selectedPiece     = nil
    validMoves        = {}
    mandatoryPieces   = {}
    Board:changeTurn()
    winner = Board:checkWinner()
end

local function handleSelection(row, col, peca)
    if multiCapturePiece then
        if row == multiCapturePiece.row and col == multiCapturePiece.col then
            selectedPiece = { row = row, col = col }
            validMoves    = Board:getValidMoves(row, col, true)
        else
            print("Você deve continuar a captura com a mesma peça!")
        end
        return
    end

    mandatoryPieces = Board:getAllPossibleCaptures()

    if peca == 0 or peca.player ~= Board.currentPlayer then return end

    if #mandatoryPieces > 0 then
        local isMandatory = false
        for _, p in ipairs(mandatoryPieces) do
            if p.row == row and p.col == col then
                isMandatory = true; break
            end
        end
        if not isMandatory then return end
    end

    selectedPiece = { row = row, col = col }
    validMoves    = Board:getValidMoves(row, col, #mandatoryPieces > 0)
end

local function handleMove(x, y, button, row, col, moveFinal)
    if not selectedPiece then return end
    if moveFinal then
        local captures = Board:movePiece(selectedPiece.row, selectedPiece.col, row, col)

        if captures and canStillCapture(row, col) then
            multiCapturePiece = { row = row, col = col }
            selectedPiece     = nil
            validMoves        = {}
            print("Capture novamente!")
        else
            endTurn()
        end
    elseif not multiCapturePiece then
        selectedPiece = nil
        validMoves    = {}
        Game.mousepressed(x, y, button)
    end
end

function Game.mousepressed(x, y, button)
    UI.mousepressed(x, y, button)

    if gameState ~= "PLAYING" or winner then return end
    if gameMode == Config.MODES.PVC and Board.currentPlayer == 2 then return end
    if button ~= 1 then return end

    local col = math.floor((x - OX) / SQUARE_SIZE) + 1
    local row = math.floor((y - OY) / SQUARE_SIZE) + 1
    if row < 1 or row > ROWS or col < 1 or col > COLS then return end

    local peca = Board:getPiece(row, col)

    if not selectedPiece then
        handleSelection(row, col, peca)
    else
        local moveFinal = nil
        for _, m in ipairs(validMoves) do
            if m.row == row and m.col == col then
                moveFinal = m; break
            end
        end
        handleMove(x, y, button, row, col, moveFinal)
    end
end

-- ─── Update ───────────────────────────────────────────────────────────────────
local function updateAI(dt)
    aiDelay = aiDelay + dt
    if aiDelay <= 1.0 then return end

    local bestMove = AI.getBestMove(Board, 3)
    if bestMove then
        local captures = Board:movePiece(bestMove.startRow, bestMove.startCol, bestMove.endRow, bestMove.endCol)
        if not (captures and canStillCapture(bestMove.endRow, bestMove.endCol)) then
            Board:changeTurn()
            winner = Board:checkWinner()
        end
    else
        winner = 1 -- IA sem movimentos: jogador 1 vence
    end
    aiDelay = 0
end

function Game.update(dt)
    UI.update(dt)
    Board:update(dt)
    aiThinking = gameState == "PLAYING" and not winner
        and gameMode == Config.MODES.PVC and Board.currentPlayer == 2

    if aiThinking then
        updateAI(dt)
    end
end

-- ─── Helpers de desenho ───────────────────────────────────────────────────────
local function screenPos(col, row)
    return OX + (col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
           OY + (row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
end

local function drawBackground()
    local w, h = Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT
    local steps = 16
    for i = 0, steps do
        local t = i / steps
        love.graphics.setColor(0.07 + 0.06 * t, 0.06 + 0.05 * t, 0.10 + 0.07 * t)
        love.graphics.rectangle("fill", 0, i * (h / steps), w, h / steps + 1)
    end
end

local function drawDecorRow()
    -- fileira decorativa de quadrados de dama no fundo
    local size = 26
    local y = Config.SCREEN_HEIGHT - 52
    for i = 0, 9 do
        local x = 40 + i * (size + 18)
        love.graphics.setColor(0.62, 0.45, 0.28, 0.25)
        love.graphics.rectangle("fill", x, y, size, size)
        love.graphics.setColor(0.95, 0.87, 0.72, 0.12)
        love.graphics.rectangle("fill", x + size / 2, y, size / 2, size / 2)
        love.graphics.rectangle("fill", x, y + size / 2, size / 2, size / 2)
    end
end

local function drawMenu()
    drawBackground()
    drawDecorRow()

    local cx = Config.SCREEN_WIDTH / 2
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(0, 0, 0, 0.5)
    local title = "DAMAS LUA"
    love.graphics.print(title, cx - fontTitle:getWidth(title) / 2 + 3, 53)
    love.graphics.setColor(1, 0.84, 0.35)
    love.graphics.print(title, cx - fontTitle:getWidth(title) / 2, 50)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.55, 0.55, 0.6)
    local sub = "Um jogo de damas em LÖVE 2D"
    love.graphics.print(sub, cx - fontSmall:getWidth(sub) / 2, 108)
    love.graphics.setFont(fontMedium)
end

local function drawCredits()
    drawBackground()
    local cx = Config.SCREEN_WIDTH / 2

    love.graphics.setFont(fontBig)
    love.graphics.setColor(1, 0.84, 0.35)
    local titleText = "CRÉDITOS"
    love.graphics.print(titleText, cx - fontBig:getWidth(titleText) / 2, 42)
    love.graphics.setFont(fontMedium)

    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.line(80, 86, Config.SCREEN_WIDTH - 80, 86)

    local entries = {
        { label = "Jogo",      value = "CheckersLua" },
        { label = "Versão",    value = "1.0" },
        { label = "Linguagem", value = "Lua" },
        { label = "Framework", value = "LÖVE 2D" },
        { label = "Licença",   value = "Apache License 2.0" },
    }
    for i, e in ipairs(entries) do
        local y = 120 + (i - 1) * 42
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.print(e.label .. ":", cx - 200, y)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(e.value, cx - 20, y)
    end

    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.line(80, 350, Config.SCREEN_WIDTH - 80, 350)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.8, 1)
    local thanks = "Obrigado por jogar!"
    love.graphics.print(thanks, cx - fontSmall:getWidth(thanks) / 2, 372)
    love.graphics.setFont(fontMedium)
end

local function drawTurnHud()
    love.graphics.setColor(0.25, 0.22, 0.28)
    love.graphics.rectangle("fill", 542, 0, Config.SCREEN_WIDTH - 542, Config.SCREEN_HEIGHT)

    love.graphics.setColor(0.4, 0.37, 0.44)
    love.graphics.rectangle("line", 543, 1, Config.SCREEN_WIDTH - 545, Config.SCREEN_HEIGHT - 2)

    -- contagem de peças
    local c1, c2 = 0, 0
    for r = 1, ROWS do
        for c = 1, COLS do
            local p = Board:getPiece(r, c)
            if p ~= 0 then
                if p.player == 1 then c1 = c1 + 1 else c2 = c2 + 1 end
            end
        end
    end

    local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 5)

    -- indicador de turno
    local turnText = "Vez de"
    local turnName = gameMode == Config.MODES.PVC
        and (Board.currentPlayer == 1 and "Você" or "IA")
        or ("Jogador " .. Board.currentPlayer)
    local turnColor = Board.currentPlayer == 1 and { 0.9, 0.25, 0.18 } or { 0.95, 0.93, 0.88 }

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print(turnText, 556, 138)

    love.graphics.setColor(turnColor[1], turnColor[2], turnColor[3], pulse)
    love.graphics.circle("fill", 562, 162, 7)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(turnName, 576, 154)

    if aiThinking then
        local txt = "IA pensando..."
        local w = fontSmall:getWidth(txt)
        love.graphics.setColor(1, 1, 1, 0.4 + 0.6 * pulse)
        love.graphics.print(txt, 650 - w / 2 - 12, 200)
    end

    -- contadores
    love.graphics.setFont(fontSmall)
    local p1y = 250
    local p2y = 290
    love.graphics.setColor(0.9, 0.25, 0.18, 0.9)
    love.graphics.circle("fill", 562, p1y + 5, 8)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.circle("fill", 562, p1y + 5, 8, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Vermelho: " .. c1, 580, p1y)

    love.graphics.setColor(0.95, 0.93, 0.88, 0.9)
    love.graphics.circle("fill", 562, p2y + 5, 8)
    love.graphics.setColor(0.25, 0.25, 0.25, 0.9)
    love.graphics.circle("fill", 562, p2y + 5, 8, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Branco: " .. c2, 580, p2y)

    love.graphics.setFont(fontMedium)
end

local function drawSelection()
    if not selectedPiece then return end

    local sx, sy = screenPos(selectedPiece.col, selectedPiece.row)
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 7)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 0.85, 0.3, 0.7 + 0.3 * pulse)
    love.graphics.circle("line", sx, sy, SQUARE_SIZE * 0.5 + pulse * 2)

    for _, m in ipairs(validMoves) do
        local mx, my = screenPos(m.col, m.row)
        if m.isCapture then
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 0.3, 0.2, 0.55 + 0.45 * pulse)
            love.graphics.circle("line", mx, my, SQUARE_SIZE * 0.42)
        else
            love.graphics.setColor(0.3, 0.85, 0.35, 0.3 + 0.25 * pulse)
            love.graphics.circle("fill", mx, my, SQUARE_SIZE * 0.18)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle("fill", mx, my, SQUARE_SIZE * 0.07)
        end
    end
end

local function drawMandatory()
    if #mandatoryPieces == 0 then return end
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 0.25, 0.15, 0.4 + 0.4 * pulse)
    for _, p in ipairs(mandatoryPieces) do
        local mx, my = screenPos(p.col, p.row)
        love.graphics.circle("line", mx, my, SQUARE_SIZE * 0.52 + pulse * 2)
    end
end

local function drawWinner()
    if not winner then return end

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)

    local cardW, cardH = 340, 170
    local cardX = (Config.SCREEN_WIDTH - cardW) / 2
    local cardY = (Config.SCREEN_HEIGHT - cardH) / 2

    love.graphics.setColor(0.14, 0.13, 0.2, 0.98)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setColor(1, 0.84, 0.35)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)

    local winColor = winner == 1 and { 0.9, 0.25, 0.18 } or { 0.95, 0.93, 0.88 }
    local texto = "Jogador " .. winner .. " Venceu!"
    if gameMode == Config.MODES.PVC then
        texto = winner == 2 and "A IA Venceu!" or "Você Venceu!"
    end

    love.graphics.setFont(fontBig)
    love.graphics.setColor(winColor[1], winColor[2], winColor[3])
    love.graphics.print(texto,
        cardX + cardW / 2 - fontBig:getWidth(texto) / 2,
        cardY + 55)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.65, 0.65, 0.7)
    local sub = "Use os botões para jogar novamente"
    love.graphics.print(sub,
        cardX + cardW / 2 - fontSmall:getWidth(sub) / 2,
        cardY + 100)
    love.graphics.setFont(fontMedium)
end

local function drawPlaying()
    -- hover só quando o jogador pode interagir
    local hoverRow, hoverCol = nil, nil
    if not winner and not (gameMode == Config.MODES.PVC and Board.currentPlayer == 2) then
        local mx, my = love.mouse.getPosition()
        local hc = math.floor((mx - OX) / SQUARE_SIZE) + 1
        local hr = math.floor((my - OY) / SQUARE_SIZE) + 1
        if hr >= 1 and hr <= ROWS and hc >= 1 and hc <= COLS then
            local hp = Board:getPiece(hr, hc)
            if hp ~= 0 and hp.player == Board.currentPlayer then
                hoverRow, hoverCol = hr, hc
            end
        end
    end

    Board:drawBoard({
        hoverRow = hoverRow,
        hoverCol = hoverCol,
        selectedRow = selectedPiece and selectedPiece.row or nil,
        selectedCol = selectedPiece and selectedPiece.col or nil,
    })
    drawTurnHud()
    drawSelection()
    drawMandatory()
    drawWinner()
end

function Game.draw()
    if gameState == "MENU" then
        drawMenu()
    elseif gameState == "CREDITS" then
        drawCredits()
    else
        drawPlaying()
    end
    UI.draw()
end

return Game
