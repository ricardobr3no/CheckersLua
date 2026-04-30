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

local selectedPiece     = nil
local validMoves        = {}
local mandatoryPieces   = {}
local multiCapturePiece = nil

-- ─── Setup ────────────────────────────────────────────────────────────────────
function Game.load()
    love.window.setTitle("CheckersLua")
    love.window.setMode(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
    Piece.loadAssets()
    -- globais usados pelo board.lua
    MoveSound    = love.audio.newSource("assets/sound_board_move_asset.wav", "static")
    CaptureSound = love.audio.newSource("assets/sound_board_jump_asset.wav", "static")
    Game.showMenu()
end

-- ─── Transições de estado ─────────────────────────────────────────────────────
function Game.showMenu()
    gameState = "MENU"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Humano vs Humano", cx - 100, 150, 200, 50, function() Game.startPlaying(Config.MODES.PVP) end)
    UI.newButton("Humano vs Computador", cx - 100, 225, 200, 50, function() Game.startPlaying(Config.MODES.PVC) end)
    UI.newButton("Créditos", cx - 100, 300, 200, 50, function() Game.showCredits() end)
    UI.newButton("Sair", cx - 100, 375, 200, 50, function() love.event.quit() end)
end

function Game.showCredits()
    gameState = "CREDITS"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Voltar", cx - 100, 420, 200, 50, function() Game.showMenu() end)
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
    Board:restart()

    UI.clear()
    UI.newButton("Menu", 525, 25, 100, 50, function() Game.showMenu() end)
    UI.newButton("Reiniciar", 525, 100, 100, 50, function() Game.startPlaying(mode) end)
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
        -- permite trocar de peça clicando em outro lugar
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

    local col = math.floor(x / SQUARE_SIZE) + 1
    local row = math.floor(y / SQUARE_SIZE) + 1
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
    if gameState == "PLAYING" and not winner then
        if gameMode == Config.MODES.PVC and Board.currentPlayer == 2 then
            updateAI(dt)
        end
    end
end

-- ─── Draw helpers ─────────────────────────────────────────────────────────────
local function drawMenu()
    love.graphics.clear(0.1, 0.1, 0.1)
    local font  = love.graphics.getFont()
    local title = "DAMAS LUA"
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, Config.SCREEN_WIDTH / 2 - font:getWidth(title) / 2, 80)
end

local function drawCredits()
    love.graphics.clear(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local cx   = Config.SCREEN_WIDTH / 2

    love.graphics.setColor(1, 0.85, 0.1)
    local titleText = "CRÉDITOS"
    love.graphics.print(titleText, cx - font:getWidth(titleText) / 2, 50)

    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.line(80, 85, Config.SCREEN_WIDTH - 80, 85)

    local entries = {
        { label = "Jogo",      value = "CheckersLua" },
        { label = "Versão",    value = "1.0" },
        { label = "Linguagem", value = "Lua" },
        { label = "Framework", value = "LÖVE 2D" },
        { label = "Licença",   value = "Apache License 2.0" },
    }
    for i, e in ipairs(entries) do
        local y = 115 + (i - 1) * 40
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(e.label .. ":", cx - 200, y)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(e.value, cx - 20, y)
    end

    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.line(80, 330, Config.SCREEN_WIDTH - 80, 330)

    love.graphics.setColor(0.5, 0.8, 1)
    local thanks = "Obrigado por jogar!"
    love.graphics.print(thanks, cx - font:getWidth(thanks) / 2, 350)
end

local function drawSelection()
    if not selectedPiece then return end

    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("line",
        (selectedPiece.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
        (selectedPiece.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
        SQUARE_SIZE * 0.45)

    for _, m in ipairs(validMoves) do
        love.graphics.setColor(m.isCapture and { 1, 0, 0, 0.6 } or { 0, 1, 0, 0.6 })
        love.graphics.circle("fill",
            (m.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
            (m.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
            SQUARE_SIZE * 0.2)
    end
end

local function drawMandatory()
    if #mandatoryPieces == 0 then return end
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 0, 0, 0.5)
    for _, p in ipairs(mandatoryPieces) do
        love.graphics.circle("line",
            (p.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
            (p.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
            SQUARE_SIZE * 0.5)
    end
end

local function drawWinner()
    if not winner then return end
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    love.graphics.setColor(1, 1, 1)
    local font  = love.graphics.getFont()
    local texto = "Jogador " .. winner .. " Venceu!"
    love.graphics.print(texto,
        Config.SCREEN_WIDTH / 2 - font:getWidth(texto) / 2,
        Config.SCREEN_HEIGHT / 2 - 20)
end

local function drawPlaying()
    Board:drawSquares()
    Board:drawPieces()
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
