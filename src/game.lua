-- Núcleo do jogo: máquina de estados (menu/créditos/partida/configurações),
-- fluxo de entrada do jogador, turnos, IA e todo o desenho da cena.
-- Recebe os callbacks do LÖVE via main.lua.
local Config            = require("src.config")
local Board             = require("src.board")
local Piece             = require("src.piece")
local UI                = require("src.ui")
local AI                = require("src.ai")
local History           = require("src.history")
local View              = require("src.view")
local Settings          = require("src.settings")

local Game              = {}

-- ─── Estado interno ───────────────────────────────────────────────────────────
local gameState         = "MENU"    -- MENU, CREDITS ou PLAYING
local gameMode          = nil       -- Config.MODES.PVP ou PVC
local winner            = nil       -- vencedor quando a partida termina
local aiDelay           = 0         -- acumulador de tempo antes de a IA jogar
local aiThinking        = false     -- true enquanto a IA está "pensando"

local selectedPiece     = nil       -- peça atualmente selecionada (row/col)
local validMoves        = {}        -- destinos válidos da peça selecionada
local mandatoryPieces   = {}        -- peças com captura obrigatória
local multiCapturePiece = nil       -- peça que ainda precisa capturar de novo

local settingsOpen      = false     -- painel de configurações aberto?
local settingsSlider    = nil       -- slider sendo arrastado (ou nil)

-- Fontes criadas no Game.load e usadas por todo o desenho.
local fontTitle  = nil
local fontBig    = nil
local fontMedium = nil
local fontSmall  = nil

-- Origem do tabuleiro na tela (canto superior esquerdo).
local OX = Config.BOARD_OFFSET_X
local OY = Config.BOARD_OFFSET_Y

-- ─── Layout do painel de configurações ────────────────────────────────────────
local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 70, 60, 510, 460 -- caixa do painel
local TRACK_X0, TRACK_X1 = 320, 515                          -- trilho dos sliders
local TOGGLE_BOX_X, TOGGLE_BOX_W = 470, 40                   -- caixa dos toggles
local SLIDER_DEFS = {  -- sliders de volume: chave de Settings, rótulo e posição
    { key = "musicVolume", label = "Música de fundo", y = 180 },
    { key = "sfxVolume",   label = "Efeitos sonoros",  y = 245 },
}
local TOGGLE_DEFS = {  -- interruptores liga/desliga
    { key = "shake", label = "Tremor de tela", y = 330 },
    { key = "hints", label = "Mostrar dicas",   y = 385 },
}
local CLOSE_RECT = { x = 255, y = 435, w = 140, h = 46 }     -- botão "Fechar"

-- ─── Setup ────────────────────────────────────────────────────────────────────
-- Inicialização única: janela, view virtual, fontes, sons e configurações.
function Game.load()
    love.window.setTitle("CheckersLua")
    love.window.setMode(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    love.graphics.setDefaultFilter("nearest", "nearest", 0)

    View.init(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)

    fontTitle  = love.graphics.newFont(42)
    fontBig    = love.graphics.newFont(26)
    fontMedium = love.graphics.newFont(18)
    fontSmall  = love.graphics.newFont(13)
    love.graphics.setFont(fontMedium)
    History.init(fontSmall) -- o histórico usa a fonte pequena

    Piece.loadAssets()
    MoveSound    = love.audio.newSource("assets/sound_board_move_asset.wav", "static")
    CaptureSound = love.audio.newSource("assets/sound_board_jump_asset.wav", "static")

    -- música de fundo (opcional: coloque assets/music.ogg|wav|mp3)
    Music = love.audio.newSource("assets/bg_awesomeness.wav", "stream")
    Music:setLooping(true)

    Settings.load()
    Game.applySettings()
    Game.showMenu()
end

-- Aplica os volumes e efeitos salvos nas configurações.
function Game.applySettings()
    local sfx = Settings.get("sfxVolume")
    MoveSound:setVolume(sfx)
    CaptureSound:setVolume(sfx)
    if Music then
        Music:setVolume(Settings.get("musicVolume"))
        if not Music:isPlaying() then
            Music:play()
        end
    end
    ShakeEnabled = Settings.get("shake")
end

-- Janela redimensionada: só precisa recalcular o view virtual.
function Game.resize(w, h)
    View.resize(w, h)
end

function Game.keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
end

-- ─── Transições de estado ─────────────────────────────────────────────────────
-- Menu principal: recria os botões centrais.
function Game.showMenu()
    gameState = "MENU"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Humano vs Humano", cx - 125, 168, 250, 54, function() Game.startPlaying(Config.MODES.PVP) end)
    UI.newButton("Humano vs Computador", cx - 125, 236, 250, 54, function() Game.startPlaying(Config.MODES.PVC) end)
    UI.newButton("Créditos", cx - 125, 304, 250, 54, function() Game.showCredits() end)
    UI.newButton("Sair", cx - 125, 372, 250, 54, function() love.event.quit() end)
    UI.newButton("Configurações", cx - 125, 440, 250, 54, function() Game.openSettings() end)
end

function Game.openSettings()
    settingsOpen = true
    settingsSlider = nil
end

local function closeSettings()
    settingsOpen = false
    settingsSlider = nil
end

-- Testa se o ponto (x,y) está dentro de um retângulo {x,y,w,h}.
local function insideRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

-- Converte a posição do mouse num valor 0..1 e aplica no slider.
local function updateSlider(key, mx)
    local val = (mx - TRACK_X0) / (TRACK_X1 - TRACK_X0)
    val = math.max(0, math.min(1, val))
    Settings.set(key, val)
    Game.applySettings()
end

-- Trata cliques dentro do painel de configurações (fechar, toggles, sliders).
local function settingsClick(x, y)
    if insideRect(x, y, CLOSE_RECT) then
        closeSettings()
        return
    end

    for _, t in ipairs(TOGGLE_DEFS) do
        local rect = { x = TOGGLE_BOX_X, y = t.y - 14, w = TOGGLE_BOX_W, h = 24 }
        if insideRect(x, y, rect) then
            Settings.set(t.key, not Settings.get(t.key))
            Game.applySettings()
            return
        end
    end

    for _, s in ipairs(SLIDER_DEFS) do
        if math.abs(y - s.y) < 16 and x >= TRACK_X0 - 6 and x <= TRACK_X1 + 6 then
            updateSlider(s.key, x)
            settingsSlider = s.key -- mantém arrastando enquanto o mouse estiver pressionado
            return
        end
    end

    -- clique fora do painel fecha as configurações
    if not insideRect(x, y, { x = PANEL_X, y = PANEL_Y, w = PANEL_W, h = PANEL_H }) then
        closeSettings()
    end
end

-- Tela de créditos.
function Game.showCredits()
    gameState = "CREDITS"
    UI.clear()
    local cx = Config.SCREEN_WIDTH / 2
    UI.newButton("Voltar", cx - 110, 470, 220, 54, function() Game.showMenu() end)
end

-- Inicia uma partida: zera todo o estado e reinicia o tabuleiro.
function Game.startPlaying(mode)
    gameState         = "PLAYING"
    gameMode          = mode
    winner            = nil
    selectedPiece     = nil
    validMoves        = {}
    mandatoryPieces   = {}
    multiCapturePiece = nil
    History.reset()
    aiDelay           = 0
    aiThinking        = false
    Board:restart()

    -- botões do painel lateral durante a partida
    UI.clear()
    UI.newButton("Menu", 548, 18, 100, 40, function() Game.showMenu() end)
    UI.newButton("Reiniciar", 548, 70, 100, 40, function() Game.startPlaying(mode) end)
    UI.newButton("Config", 548, 122, 100, 40, function() Game.openSettings() end)
end

-- ─── Input ────────────────────────────────────────────────────────────────────
-- A peça em (row,col) ainda pode fazer outra captura? (captura em cadeia)
local function canStillCapture(row, col)
    local moves = Board:getValidMoves(row, col, true)
    for _, m in ipairs(moves) do
        if m.isCapture then return true end
    end
    return false
end

-- Encerra o turno: limpa a seleção, troca o jogador e confere o vencedor.
local function endTurn()
    multiCapturePiece = nil
    selectedPiece     = nil
    validMoves        = {}
    mandatoryPieces   = {}
    Board:changeTurn()
    winner = Board:checkWinner()
end

-- Seleciona uma peça e calcula seus movimentos válidos, respeitando:
-- captura obrigatória, captura em cadeia e vez do jogador.
local function handleSelection(row, col, peca)
    -- em cadeia de captura, só a mesma peça pode ser escolhida
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

    -- casa vazia ou peça do adversário não seleciona
    if peca == 0 or peca.player ~= Board.currentPlayer then return end

    -- se existe captura obrigatória, só peças que capturam podem ser escolhidas
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

-- Executa o movimento da peça selecionada para o destino clicado.
local function handleMove(x, y, button, row, col, moveFinal)
    if not selectedPiece then return end
    if moveFinal then
        local piece = Board:getPiece(selectedPiece.row, selectedPiece.col)
        local captures = Board:movePiece(selectedPiece.row, selectedPiece.col, row, col)
        History.record(piece, row, col, captures)

        -- captura em cadeia: não troca o turno enquanto puder capturar de novo
        if captures and canStillCapture(row, col) then
            multiCapturePiece = { row = row, col = col }
            selectedPiece     = nil
            validMoves        = {}
            print("Capture novamente!")
        else
            History.commit()
            endTurn()
        end
    elseif not multiCapturePiece then
        -- clique numa casa sem movimento: desmarca e tenta nova seleção
        selectedPiece = nil
        validMoves    = {}
        Game.mousepressed(x, y, button)
    end
end

-- Trata cliques do mouse: painel de config, botões UI, scrollbar do
-- histórico e, em jogo, seleção/movimentação de peças.
function Game.mousepressed(x, y, button)
    x, y = View.toVirtual(x, y)

    if settingsOpen then
        settingsClick(x, y)
        return
    end

    UI.mousepressed(x, y, button)

    if gameState ~= "PLAYING" or winner then return end

    -- clique na scrollbar do histórico não interage com o tabuleiro
    if History.mousepressed(x, y, button) then return end

    -- em PVC, cliques não fazem nada durante o turno da IA
    if gameMode == Config.MODES.PVC and Board.currentPlayer == 2 then return end
    if button ~= 1 then return end

    -- converte o clique em casa do tabuleiro (row/col)
    local col = math.floor((x - OX) / SQUARE_SIZE) + 1
    local row = math.floor((y - OY) / SQUARE_SIZE) + 1
    if row < 1 or row > ROWS or col < 1 or col > COLS then return end

    local peca = Board:getPiece(row, col)

    if not selectedPiece then
        handleSelection(row, col, peca)
    else
        -- o clique é um destino válido da peça selecionada?
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
-- Roda o turno da IA: espera um pequeno atraso, calcula a melhor jogada e
-- executa (incluindo capturas em cadeia, que não trocam o turno).
local function updateAI(dt)
    aiDelay = aiDelay + dt
    if aiDelay <= 1.0 then return end -- pausa de 1s antes de jogar

    local bestMove = AI.getBestMove(Board, 3)
    if bestMove then
        local piece = Board:getPiece(bestMove.startRow, bestMove.startCol)
        local captures = Board:movePiece(bestMove.startRow, bestMove.startCol, bestMove.endRow, bestMove.endCol)
        History.record(piece, bestMove.endRow, bestMove.endCol, captures)
        if not (captures and canStillCapture(bestMove.endRow, bestMove.endCol)) then
            History.commit()
            Board:changeTurn()
            winner = Board:checkWinner()
        end
    else
        winner = 1 -- IA sem movimentos: jogador 1 vence
    end
    aiDelay = 0
end

-- Roda do mouse repassada para a rolagem do histórico.
function Game.wheelmoved(x, y)
    History.wheel(x, y)
end

function Game.update(dt)
    UI.update(dt)
    Board:update(dt)
    History.update(dt)

    -- arrastar slider do painel de configurações enquanto o mouse estiver preso
    if settingsOpen then
        if settingsSlider and love.mouse.isDown(1) then
            local mx = View.toVirtual(love.mouse.getPosition())
            updateSlider(settingsSlider, mx)
        elseif settingsSlider then
            settingsSlider = nil
        end
    end

    -- a IA "pensa" quando é a vez dela em PVC
    aiThinking = gameState == "PLAYING" and not winner
        and gameMode == Config.MODES.PVC and Board.currentPlayer == 2

    if aiThinking then
        updateAI(dt)
    end
end

-- ─── Helpers de desenho ───────────────────────────────────────────────────────
-- Centro em pixels da casa (col,row) do tabuleiro.
local function screenPos(col, row)
    return OX + (col - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
           OY + (row - 1) * SQUARE_SIZE + SQUARE_SIZE / 2
end

-- Fundo com gradiente vertical sutil (mais escuro embaixo).
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
    for i = 0, 13 do
        local x = 40 + i * (size + 18)
        love.graphics.setColor(0.62, 0.45, 0.28, 0.25)
        love.graphics.rectangle("fill", x, y, size, size)
        love.graphics.setColor(0.95, 0.87, 0.72, 0.12)
        love.graphics.rectangle("fill", x + size / 2, y, size / 2, size / 2)
        love.graphics.rectangle("fill", x, y + size / 2, size / 2, size / 2)
    end
end

-- Menu principal: título com sombra e subtítulo.
local function drawMenu()
    drawBackground()
    drawDecorRow()

    local cx = Config.SCREEN_WIDTH / 2
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(0, 0, 0, 0.5)
    local title = "DAMAS LUA"
    love.graphics.print(title, cx - fontTitle:getWidth(title) / 2 + 3, 53) -- sombra
    love.graphics.setColor(1, 0.84, 0.35)
    love.graphics.print(title, cx - fontTitle:getWidth(title) / 2, 50)    -- texto

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.55, 0.55, 0.6)
    local sub = "Um jogo de damas em LÖVE 2D"
    love.graphics.print(sub, cx - fontSmall:getWidth(sub) / 2, 108)
    love.graphics.setFont(fontMedium)
end

-- Tela de créditos: tabela de informações + agradecimento.
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

-- Painel lateral durante a partida: indicador de turno, contagem de peças
-- e o histórico de jogadas.
local function drawTurnHud()
    -- fundo do painel + borda
    love.graphics.setColor(0.25, 0.22, 0.28)
    love.graphics.rectangle("fill", 542, 0, Config.SCREEN_WIDTH - 542, Config.SCREEN_HEIGHT)

    love.graphics.setColor(0.4, 0.37, 0.44)
    love.graphics.rectangle("line", 543, 1, Config.SCREEN_WIDTH - 545, Config.SCREEN_HEIGHT - 2)

    local PANEL_RIGHT = Config.SCREEN_WIDTH - 6

    -- contagem de peças de cada jogador
    local c1, c2 = 0, 0
    for r = 1, ROWS do
        for c = 1, COLS do
            local p = Board:getPiece(r, c)
            if p ~= 0 then
                if p.player == 1 then c1 = c1 + 1 else c2 = c2 + 1 end
            end
        end
    end

    local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 5) -- animação de pulsar
    love.graphics.setFont(fontSmall)

    -- texto alinhado à direita do painel (nunca estoura a tela)
    local function rightText(y, txt, r, g, b, a)
        love.graphics.setColor(r, g, b, a or 1)
        local w = fontSmall:getWidth(txt)
        love.graphics.print(txt, PANEL_RIGHT - w, y)
        return PANEL_RIGHT - w
    end

    -- indicador de turno
    local turnText = "Vez de"
    local turnName = gameMode == Config.MODES.PVC
        and (Board.currentPlayer == 1 and "Você" or "IA")
        or ("Jogador " .. Board.currentPlayer)
    local turnColor = Board.currentPlayer == 1 and { 0.9, 0.25, 0.18 } or { 0.95, 0.93, 0.88 }

    rightText(186, turnText, 0.7, 0.7, 0.75)
    local nameX = rightText(204, turnName, 1, 1, 1)
    love.graphics.setColor(turnColor[1], turnColor[2], turnColor[3], pulse)
    love.graphics.circle("fill", nameX - 12, 212, 7)

    if aiThinking then
        local txt = "IA pensando..."
        local w = fontSmall:getWidth(txt)
        local centerX = 542 + (Config.SCREEN_WIDTH - 542) / 2
        love.graphics.setColor(1, 1, 1, 0.4 + 0.6 * pulse)
        love.graphics.print(txt, centerX - w / 2, 252)
    end

    -- contadores
    local p1y = 302
    local p2y = 342
    love.graphics.setColor(0.9, 0.25, 0.18, 0.9)
    love.graphics.circle("fill", 550, p1y + 5, 8)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.circle("fill", 550, p1y + 5, 8, 4, 4)
    rightText(p1y, "Vermelho: " .. c1, 1, 1, 1)

    love.graphics.setColor(0.95, 0.93, 0.88, 0.9)
    love.graphics.circle("fill", 550, p2y + 5, 8)
    love.graphics.setColor(0.25, 0.25, 0.25, 0.9)
    love.graphics.circle("fill", 550, p2y + 5, 8, 4, 4)
    rightText(p2y, "Branco: " .. c2, 1, 1, 1)

    History.draw()
    love.graphics.setFont(fontMedium)
end

-- Destaca a peça selecionada e os destinos válidos (círculos pulsantes).
-- Capturas aparecem como anel vermelho; movimentos como ponto verde.
local function drawSelection()
    if not selectedPiece then return end

    local sx, sy = screenPos(selectedPiece.col, selectedPiece.row)
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 7)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 0.85, 0.3, 0.7 + 0.3 * pulse)
    love.graphics.circle("line", sx, sy, SQUARE_SIZE * 0.5 + pulse * 2)

    for _, m in ipairs(validMoves) do
        if not Settings.get("hints") then break end
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

-- Destaca com um anel as peças com captura obrigatória (quando as dicas estão ligadas).
local function drawMandatory()
    if #mandatoryPieces == 0 or not Settings.get("hints") then return end
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 0.25, 0.15, 0.4 + 0.4 * pulse)
    for _, p in ipairs(mandatoryPieces) do
        local mx, my = screenPos(p.col, p.row)
        love.graphics.circle("line", mx, my, SQUARE_SIZE * 0.52 + pulse * 2)
    end
end

-- Sobreposição de fim de jogo: cartão com o vencedor e a mensagem.
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

-- Painel de configurações sobreposto à cena (escurece o fundo atrás).
local function drawSettings()
    -- máscara translúcida sobre o jogo
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)

    love.graphics.setColor(0.13, 0.12, 0.18, 0.98)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 14, 14)
    love.graphics.setColor(1, 0.84, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 14, 14)

    love.graphics.setFont(fontBig)
    love.graphics.setColor(1, 1, 1)
    local title = "CONFIGURAÇÕES"
    love.graphics.print(title, PANEL_X + PANEL_W / 2 - fontBig:getWidth(title) / 2, PANEL_Y + 22)

    love.graphics.setFont(fontMedium)

    -- sliders
    for _, s in ipairs(SLIDER_DEFS) do
        love.graphics.setColor(0.75, 0.75, 0.8)
        love.graphics.print(s.label, 130, s.y - 22)

        local val = Settings.get(s.key)

        love.graphics.setColor(0.3, 0.28, 0.38)
        love.graphics.rectangle("fill", TRACK_X0, s.y, TRACK_X1 - TRACK_X0, 10, 5, 5)

        local filledW = (TRACK_X1 - TRACK_X0) * val
        love.graphics.setColor(0.35, 0.65, 1)
        love.graphics.rectangle("fill", TRACK_X0, s.y, filledW, 10, 5, 5)

        local knobX = TRACK_X0 + (TRACK_X1 - TRACK_X0) * val
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", knobX, s.y + 5, 9)
        love.graphics.setColor(0.2, 0.35, 0.6)
        love.graphics.circle("line", knobX, s.y + 5, 9)

        love.graphics.setFont(fontSmall)
        local pct = string.format("%d%%", math.floor(val * 100))
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.print(pct, TRACK_X1 + 12, s.y)
        love.graphics.setFont(fontMedium)
    end

    -- toggles
    for _, t in ipairs(TOGGLE_DEFS) do
        love.graphics.setColor(0.75, 0.75, 0.8)
        love.graphics.print(t.label, 130, t.y - 8)

        local on = Settings.get(t.key)
        local boxY = t.y - 14
        if on then
            love.graphics.setColor(0.2, 0.75, 0.35)
        else
            love.graphics.setColor(0.35, 0.35, 0.42)
        end
        love.graphics.rectangle("fill", TOGGLE_BOX_X, boxY, TOGGLE_BOX_W, 24, 12, 12)

        local knobX = on and (TOGGLE_BOX_X + TOGGLE_BOX_W - 20) or TOGGLE_BOX_X
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", knobX + 10, boxY + 12, 9)
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.circle("line", knobX + 10, boxY + 12, 9)
    end

    -- botão fechar
    local mx, my = View.toVirtual(love.mouse.getPosition())
    local hover = insideRect(mx, my, CLOSE_RECT)

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", CLOSE_RECT.x + 2, CLOSE_RECT.y + 3, CLOSE_RECT.w, CLOSE_RECT.h, 12, 12)
    love.graphics.setColor(hover and 0.26 or 0.16, hover and 0.32 or 0.20, hover and 0.46 or 0.30)
    love.graphics.rectangle("fill", CLOSE_RECT.x, CLOSE_RECT.y, CLOSE_RECT.w, CLOSE_RECT.h, 12, 12)
    love.graphics.setColor(0.62, 0.70, 0.9, hover and 0.9 or 0.45)
    love.graphics.rectangle("line", CLOSE_RECT.x, CLOSE_RECT.y, CLOSE_RECT.w, CLOSE_RECT.h, 12, 12)

    love.graphics.setColor(1, 1, 1)
    local label = "Fechar"
    love.graphics.print(label,
        CLOSE_RECT.x + CLOSE_RECT.w / 2 - fontMedium:getWidth(label) / 2,
        CLOSE_RECT.y + CLOSE_RECT.h / 2 - fontMedium:getHeight() / 2)
end

-- Cena de jogo: calcula o hover e desenha tabuleiro, painel e destaques.
local function drawPlaying()
    -- hover só quando o jogador pode interagir
    local hoverRow, hoverCol = nil, nil
    if not winner and not (gameMode == Config.MODES.PVC and Board.currentPlayer == 2) then
        local mx, my = View.toVirtual(love.mouse.getPosition())
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

-- Desenha tudo conforme o estado atual, dentro do view virtual.
function Game.draw()
    love.graphics.clear(0.02, 0.02, 0.04)
    View.apply()
    if gameState == "MENU" then
        drawMenu()
    elseif gameState == "CREDITS" then
        drawCredits()
    else
        drawPlaying()
    end
    UI.draw()          -- botões (menus, créditos e painel da partida)
    if settingsOpen then
        drawSettings() -- painel de configurações por cima de tudo
    end
    View.release()
end

return Game
