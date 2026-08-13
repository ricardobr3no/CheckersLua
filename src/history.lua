-- Histórico de jogadas no painel lateral, com notação algébrica estilo
-- xadrez: "a3-b4" (movimento), "a3xc5" (captura), "a3xc5xe7" (captura em
-- cadeia) e sufixo "=D" para promoção a dama.
-- Inclui scroll com barra arrastável e roda do mouse quando o histórico
-- excede a altura do painel. A lista de linhas é cacheada (invalida-se
-- quando uma jogada é gravada ou o histórico é reiniciado).
local Config = require("src.config")
local Board  = require("src.board")
local View   = require("src.view")

local History = {}

-- ─── Layout ────────────────────────────────────────────────────────────────────
local X, TOP       = 548, 398          -- área de texto (x e topo)
local BOTTOM       = Config.SCREEN_HEIGHT - 6 -- limite inferior da lista
local LINE_H       = 16                -- altura de cada linha
local TRACK_X      = Config.SCREEN_WIDTH - 10 -- x do trilho da scrollbar
local TRACK_W      = 6                 -- largura do trilho
local WHEEL_STEP   = 24                -- pixels por "clique" da roda
local BOX_X        = 544               -- x do fundo (caixa)
local BOX_MARGIN_Y = 24                -- espaço acima do topo p/ o título

-- ─── Estado ────────────────────────────────────────────────────────────────────
local moves      = {}   -- notações completas (uma por jogada finalizada)
local pending    = nil  -- jogada em andamento (captura em cadeia)
local scroll     = 0    -- deslocamento vertical em pixels (0 = topo)
local follow     = true -- true = manter rolando até a jogada mais nova
local dragging   = nil  -- offset do mouse ao arrastar a scrollbar
local font       = nil  -- fonte definida em History.init
local linesCache = nil  -- linhas de texto prontas (cache de buildLines)

-- ─── Notação algébrica ─────────────────────────────────────────────────────────
-- Converte (row,col) do tabuleiro para a notação. A base do jogador 1
-- (linha 8 da tela) é a rank 1, como no xadrez.
local function squareName(row, col)
    return string.char(string.byte("a") + col - 1) .. (ROWS - row + 1)
end

-- ─── Linhas exibíveis (com quebra de linha) ────────────────────────────────────
-- Quebra um texto em linhas que caibam em maxW pixels (evita estourar o painel).
local function wrapLine(text, maxW)
    if font:getWidth(text) <= maxW then return { text } end
    local out, cur = {}, ""
    for i = 1, #text do
        local c = text:sub(i, i)
        if font:getWidth(cur .. c) > maxW then
            out[#out + 1] = cur
            cur = c
        else
            cur = cur .. c
        end
    end
    if #cur > 0 then out[#out + 1] = cur end
    return out
end

-- Monta as linhas de texto exibíveis, agrupando as jogadas aos pares
-- ("1. a3-b4 a6-b5"). Se uma linha for larga demais, quebra em mais linhas.
local function buildLines()
    local out = {}
    local maxW = Config.SCREEN_WIDTH - 556
    for i = 1, #moves, 2 do
        local p1, p2 = moves[i], moves[i + 1]
        local num = math.floor((i + 1) / 2) .. ". "
        local line1 = num .. p1
        local single = p2 and (line1 .. " " .. p2) or line1

        if p2 and font:getWidth(single) <= maxW then
            out[#out + 1] = single
        else
            for _, l in ipairs(wrapLine(line1, maxW)) do out[#out + 1] = l end
            if p2 then
                for _, l in ipairs(wrapLine("   " .. p2, maxW)) do out[#out + 1] = l end
            end
        end
    end
    return out
end

-- Dimensões de rolagem: altura visível, altura total e deslocamento máximo.
local function scrollInfo()
    if not linesCache then linesCache = buildLines() end
    local visH = BOTTOM - TOP
    local contentH = #linesCache * LINE_H
    local max = math.max(0, contentH - visH)
    return visH, contentH, max
end

-- Retângulo do "polegar" da scrollbar, proporcional ao conteúdo visível.
local function thumbRect(visH, contentH, max)
    local thumbH = math.max(20, visH * visH / contentH)
    local thumbY = TOP + (visH - thumbH) * (scroll / max)
    return TRACK_X, thumbY, TRACK_W, thumbH
end

-- Mantém o scroll dentro dos limites e decide se continua seguindo a última.
local function clampScroll(max)
    scroll = math.max(0, math.min(scroll, max))
    follow = scroll >= max
end

-- ─── API ───────────────────────────────────────────────────────────────────────
-- Define a fonte do texto e limpa o histórico. Chamado no Game.load.
function History.init(smallFont)
    font = smallFont
    History.reset()
end

-- Reinicia o histórico (nova partida).
function History.reset()
    moves, pending = {}, nil
    scroll, follow, dragging = 0, true, nil
    linesCache = nil
end

-- Acumula um passo de movimento. Capturas em cadeia chamam várias vezes
-- até History.commit; cada chamada acrescenta a casa de chegada.
function History.record(piece, toRow, toCol, isCapture)
    if not pending then
        pending = {
            squares = { piece.row, piece.col }, -- pares (row,col) por passo
            wasKing = piece.isKing,             -- estado antes da jogada
            captures = {},                      -- marca cada passo que captura
        }
    end
    table.insert(pending.squares, toRow)
    table.insert(pending.squares, toCol)
    if isCapture then
        table.insert(pending.captures, true)
    end
end

-- Finaliza a jogada atual, gera a notação e a adiciona ao histórico.
-- Ex.: "a3-b4", "a3xc5", "a3xc5xe7", "...=D" (promoção a dama).
function History.commit()
    if not pending then return end

    local s = pending.squares
    local toRow, toCol = s[#s - 1], s[#s]
    local dest = Board:getPiece(toRow, toCol)
    local promoted = dest ~= 0 and dest.isKing and not pending.wasKing

    local notation
    if #pending.captures > 0 then
        -- captura (possivelmente em cadeia): casa inicial e cada chegada com "x"
        local parts = {}
        for i = 1, #s, 2 do
            parts[#parts + 1] = squareName(s[i], s[i + 1])
        end
        notation = table.concat(parts, "x")
    else
        notation = squareName(s[1], s[2]) .. "-" .. squareName(toRow, toCol)
    end
    if promoted then
        notation = notation .. "=D"
    end

    moves[#moves + 1] = notation
    pending, linesCache = nil, nil -- invalida o cache das linhas
    follow = true                  -- rola até a jogada mais nova
end

-- ─── Input ─────────────────────────────────────────────────────────────────────
-- Roda do mouse: rola o histórico (y positivo = rolar para cima).
function History.wheel(x, y)
    if y == 0 or #moves == 0 then return end
    local visH, contentH, max = scrollInfo()
    if max <= 0 then return end
    scroll = scroll - y * WHEEL_STEP
    clampScroll(max)
end

-- Retorna true se o clique foi consumido pela scrollbar (inicia o arrasto).
function History.mousepressed(x, y, button)
    if button ~= 1 or #moves == 0 then return false end
    local visH, contentH, max = scrollInfo()
    if max <= 0 then return false end
    local tx, ty, tw, th = thumbRect(visH, contentH, max)
    if x >= tx and x <= tx + tw and y >= ty and y <= ty + th then
        dragging = y - ty -- guarda onde o mouse "segurou" no polegar
        return true
    end
    return false
end

-- Durante o arrasto, move o polegar acompanhando o mouse.
function History.update(dt)
    if not dragging then return end
    if not love.mouse.isDown(1) then
        dragging = nil
        return
    end
    local mx, my = View.toVirtual(love.mouse.getPosition())
    local visH, contentH, max = scrollInfo()
    if max <= 0 then return end
    local thumbH = math.max(20, visH * visH / contentH)
    local t = math.max(0, math.min(1, (my - dragging - TOP) / (visH - thumbH)))
    scroll = t * max
    follow = scroll >= max
end

-- ─── Desenho ───────────────────────────────────────────────────────────────────
function History.draw()
    if #moves == 0 then return end

    local visH, contentH, max = scrollInfo()
    if follow then scroll = max end
    scroll = math.max(0, math.min(scroll, max))

    -- caixa de fundo com borda, distinta do painel
    local boxX, boxY = BOX_X, TOP - BOX_MARGIN_Y
    local boxW = Config.SCREEN_WIDTH - boxX - 4
    local boxH = BOTTOM - boxY
    love.graphics.setColor(0.15, 0.21, 0.28)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setColor(0.35, 0.48, 0.62, 0.5)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)

    -- título
    love.graphics.setFont(font)
    love.graphics.setColor(0.6, 0.6, 0.68)
    love.graphics.print("Histórico", X, TOP - 18)

    -- linhas, recortadas aos limites do painel (nada desenha fora da caixa)
    local y = TOP - scroll
    for _, line in ipairs(linesCache) do
        if y + LINE_H > BOTTOM then break end
        if y >= TOP - LINE_H then
            love.graphics.setColor(1, 1, 1, 0.92)
            love.graphics.print(line, X, y)
        end
        y = y + LINE_H
    end

    -- scrollbar (só aparece quando o histórico extrapola)
    if max > 0 then
        local tx, ty, tw, th = thumbRect(visH, contentH, max)
        love.graphics.setColor(0.3, 0.28, 0.38)
        love.graphics.rectangle("fill", TRACK_X, TOP, TRACK_W, visH)
        love.graphics.setColor(0.62, 0.60, 0.72)
        love.graphics.rectangle("fill", tx, ty, tw, th)
    end
end

return History
