Config = require("config")
Board = require("board")
Piece = require("piece")
UI = require("ui")
AI = require("ai")

local selectedPiece = nil
local mandatoryPieces = {}
local multiCapturePiece = nil
local validMoves = {}
local winner = nil
local gameMode = nil
local gameState = "MENU" -- "MENU" ou "PLAYING"
local aiDelay = 0

function love.load()
    love.window.setTitle("CheckersLua")
    love.window.setMode(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    Piece.loadAssets()
    showMenu()
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
    -- audios
    moveSound = love.audio.newSource("assets/sound_board_move_asset.wav", "static")
    captureSound = love.audio.newSource("assets/sound_board_jump_asset.wav", "static")
end

function showMenu()
    gameState = "MENU"
    UI.clear()
    local centerX = Config.SCREEN_WIDTH / 2
    UI.newButton("Humano vs Humano", centerX - 100, 150, 200, 50, function()
        startPlaying(Config.MODES.PVP)
    end)
    UI.newButton("Humano vs Computador", centerX - 100, 225, 200, 50, function()
        startPlaying(Config.MODES.PVC)
    end)
    UI.newButton("Créditos", centerX - 100, 300, 200, 50, function()
        showCredits()
    end)
    UI.newButton("Sair", centerX - 100, 375, 200, 50, function()
        love.event.quit()
    end)
end

function showCredits()
    gameState = "CREDITS"
    UI.clear()
    local centerX = Config.SCREEN_WIDTH / 2
    UI.newButton("Voltar", centerX - 100, 420, 200, 50, function()
        showMenu()
    end)
end

function startPlaying(mode)
    gameState = "PLAYING"
    gameMode = mode
    Board:restart()
    winner = nil
    selectedPiece = nil
    validMoves = {}
    multiCapturePiece = nil
    mandatoryPieces = {}
    aiDelay = 0

    UI.clear()
    UI.newButton("Menu", 525, 25, 100, 50, function()
        showMenu()
    end)
    UI.newButton("Reiniciar", 525, 100, 100, 50, function()
        startPlaying(mode)
    end)
end

function love.mousepressed(x, y, button)
    -- verificar se o mouse foi clicado em algum botao
    UI.mousepressed(x, y, button)

    if gameState ~= "PLAYING" or winner then
        return
    end

    -- No modo PVC, impede o jogador de mover as peças do Computador (Player 2)
    if gameMode == Config.MODES.PVC and Board.currentPlayer == 2 then
        return
    end

    if button == 1 then
        local col = math.floor(x / SQUARE_SIZE) + 1
        local row = math.floor(y / SQUARE_SIZE) + 1
        if row < 1 or row > ROWS or col < 1 or col > COLS then
            return
        end

        local peca = Board:getPiece(row, col)

        if not selectedPiece then
            -- Se estamos em multicapture, o jogador SÓ pode selecionar a peça que já moveu
            if multiCapturePiece then
                if row == multiCapturePiece.row and col == multiCapturePiece.col then
                    selectedPiece = { row = row, col = col }
                    validMoves = Board:getValidMoves(row, col, true) -- Força apenas capturas
                else
                    print("Você deve continuar a captura com a mesma peça!")
                    return
                end
            else
                -- Lógica normal de seleção
                mandatoryPieces = Board:getAllPossibleCaptures()

                if peca ~= 0 and peca.player == Board.currentPlayer then
                    if #mandatoryPieces > 0 then
                        local isMandatory = false
                        for _, p in ipairs(mandatoryPieces) do
                            if p.row == row and p.col == col then
                                isMandatory = true
                                break
                            end
                        end
                        if not isMandatory then
                            return
                        end
                    end
                    selectedPiece = { row = row, col = col }
                    validMoves = Board:getValidMoves(row, col, #mandatoryPieces > 0)
                end
            end
        else
            -- Tentar mover
            local moveFinal = nil
            for _, m in ipairs(validMoves) do
                if m.row == row and m.col == col then
                    moveFinal = m
                    break
                end
            end

            if moveFinal then
                local captures = Board:movePiece(selectedPiece.row, selectedPiece.col, row, col)

                -- Checar se pode continuar capturando
                local canStillCapture = false
                if captures then
                    local nextMoves = Board:getValidMoves(row, col, true)
                    for _, m in ipairs(nextMoves) do
                        if m.isCapture then
                            canStillCapture = true
                            break
                        end
                    end
                end

                if canStillCapture then
                    -- Mantém o turno e obriga a usar esta peça
                    multiCapturePiece = { row = row, col = col }
                    selectedPiece = nil
                    validMoves = {}
                    print("Capture novamente!")
                else
                    -- Finaliza o turno normalmente
                    multiCapturePiece = nil
                    selectedPiece = nil
                    validMoves = {}
                    mandatoryPieces = {}
                    Board:changeTurn()

                    winner = Board:checkWinner()
                end
            else
                -- Se não clicou num movimento válido e não está em multicapture, permite trocar a peça
                if not multiCapturePiece then
                    selectedPiece = nil
                    validMoves = {}
                    love.mousepressed(x, y, button) -- recursao, quando mudar de posicao ja entra selecionado
                end
            end
        end
    end
end

function love.update(dt)
    UI.update(dt)

    if gameState == "PLAYING" and not winner then
        -- Lógica da IA
        if gameMode == Config.MODES.PVC and Board.currentPlayer == 2 then
            aiDelay = aiDelay + dt
            if aiDelay > 1.0 then -- Atraso de 1 segundo para a IA mover
                local bestMove = AI.getBestMove(Board, 3)
                if bestMove then
                    local captures =
                        Board:movePiece(bestMove.startRow, bestMove.startCol, bestMove.endRow, bestMove.endCol)

                    -- Se capturou, checar se pode continuar capturando (multicapture)
                    local canStillCapture = false
                    if captures then
                        local nextMoves = Board:getValidMoves(bestMove.endRow, bestMove.endCol, true)
                        for _, m in ipairs(nextMoves) do
                            if m.isCapture then
                                canStillCapture = true
                                break
                            end
                        end
                    end

                    if not canStillCapture then
                        Board:changeTurn()
                        winner = Board:checkWinner()
                    end
                else
                    -- IA não tem movimentos, ela perdeu
                    winner = 1
                end
                aiDelay = 0
            end
        end
    end
end

function love.draw()
    if gameState == "MENU" then
        love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local title = "DAMAS LUA"
        love.graphics.print(title, Config.SCREEN_WIDTH / 2 - font:getWidth(title) / 2, 80)
    elseif gameState == "CREDITS" then
        love.graphics.clear(0.1, 0.1, 0.1)
        local font = love.graphics.getFont()
        local cx = Config.SCREEN_WIDTH / 2

        -- Título
        love.graphics.setColor(1, 0.85, 0.1)
        local titleText = "CRÉDITOS"
        love.graphics.print(titleText, cx - font:getWidth(titleText) / 2, 50)

        -- Linha separadora
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.line(80, 85, Config.SCREEN_WIDTH - 80, 85)

        -- Informações
        local lines = {
            { label = "Jogo",      value = "CheckersLua" },
            { label = "Versão",    value = "1.0" },
            { label = "Linguagem", value = "Lua" },
            { label = "Framework", value = "LÖVE 2D" },
            { label = "Licença",   value = "Apache License 2.0" },
        }

        local startY = 115
        local lineH = 40
        for i, entry in ipairs(lines) do
            local y = startY + (i - 1) * lineH

            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print(entry.label .. ":", cx - 200, y)

            love.graphics.setColor(1, 1, 1)
            love.graphics.print(entry.value, cx - 20, y)
        end

        -- Linha separadora inferior
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.line(80, 330, Config.SCREEN_WIDTH - 80, 330)

        -- Agradecimento
        love.graphics.setColor(0.5, 0.8, 1)
        local thanks = "Obrigado por jogar!"
        love.graphics.print(thanks, cx - font:getWidth(thanks) / 2, 350)
    else
        Board:drawSquares()
        Board:drawPieces()

        -- Desenha destaque da seleção
        if selectedPiece then
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 1, 0)
            love.graphics.circle(
                "line",
                (selectedPiece.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                (selectedPiece.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                SQUARE_SIZE * 0.45
            )

            for _, m in ipairs(validMoves) do
                if m.isCapture then
                    love.graphics.setColor(1, 0, 0, 0.6)
                else
                    love.graphics.setColor(0, 1, 0, 0.6)
                end
                love.graphics.circle(
                    "fill",
                    (m.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                    (m.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                    SQUARE_SIZE * 0.2
                )
            end
        end

        -- Peças com captura obrigatória
        if #mandatoryPieces > 0 then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1, 0, 0, 0.5)
            for _, p in ipairs(mandatoryPieces) do
                love.graphics.circle(
                    "line",
                    (p.col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                    (p.row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
                    SQUARE_SIZE * 0.5
                )
            end
        end

        -- Vitória
        if winner then
            love.graphics.setColor(0, 0, 0, 0.75)
            love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
            love.graphics.setColor(1, 1, 1)
            local font = love.graphics.getFont()
            local texto = "Jogador " .. winner .. " Venceu!"
            love.graphics.print(
                texto,
                Config.SCREEN_WIDTH / 2 - font:getWidth(texto) / 2,
                Config.SCREEN_HEIGHT / 2 - 20
            )
        end
    end

    UI.draw()
end
