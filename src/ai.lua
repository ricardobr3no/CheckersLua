-- IA do jogador 2 (branco) usando Minimax com poda alfa-beta.
-- Para cada jogada possível simula as respostas do adversário até uma
-- profundidade fixa e escolhe a jogada com melhor pontuação final.
local AI = {}

-- Valores das peças para a função de avaliação
local PIECE_VALUE = 10
local KING_VALUE = 30

-- Avalia uma posição do ponto de vista da IA (jogador 2 = positivo).
-- Soma peças próprias e subtrai as do adversário (dama vale mais).
function AI.evaluate(boardInstance)
    local score = 0
    for r = 1, 8 do
        for c = 1, 8 do
            local p = boardInstance:getPiece(r, c)
            if p ~= 0 then
                local value = p.isKing and KING_VALUE or PIECE_VALUE
                if p.player == 2 then -- IA (Assumindo que IA é sempre jogador 2)
                    score = score + value
                else
                    score = score - value
                end
            end
        end
    end
    return score
end

-- Retorna a melhor jogada para o jogador da vez no tabuleiro dado.
-- Enumeram-se todos os movimentos legais (capturas obrigatórias primeiro) e
-- cada um é avaliado pela minimax; retorna o movimento de maior pontuação.
function AI.getBestMove(boardInstance, depth)
    local bestScore = -math.huge
    local bestMove = nil

    -- coleta de todos os movimentos legais da posição atual
    local allMoves = {}
    local mandatory = boardInstance:getAllPossibleCaptures()

    if #mandatory > 0 then
        for _, pPos in ipairs(mandatory) do
            local moves = boardInstance:getValidMoves(pPos.row, pPos.col, true)
            for _, m in ipairs(moves) do
                table.insert(allMoves,
                    { startRow = pPos.row, startCol = pPos.col, endRow = m.row, endCol = m.col, isCapture = true })
            end
        end
    else
        for r = 1, 8 do
            for c = 1, 8 do
                local p = boardInstance:getPiece(r, c)
                if p ~= 0 and p.player == boardInstance.currentPlayer then
                    local moves = boardInstance:getValidMoves(r, c, false)
                    for _, m in ipairs(moves) do
                        table.insert(allMoves,
                            { startRow = r, startCol = c, endRow = m.row, endCol = m.col, isCapture = m.isCapture })
                    end
                end
            end
        end
    end

    -- testa cada movimento numa cópia do tabuleiro e mantém o melhor
    for _, move in ipairs(allMoves) do
        local tempBoard = boardInstance:copy()
        tempBoard:movePiece(move.startRow, move.startCol, move.endRow, move.endCol)
        tempBoard:changeTurn()

        local score = AI.minimax(tempBoard, depth - 1, -math.huge, math.huge, false)
        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end

    return bestMove
end

-- Minimax com poda alfa-beta. isMaximizing = true quando é a vez da IA
-- (quer maximizar), false quando é a vez do jogador (quer minimizar).
function AI.minimax(boardInstance, depth, alpha, beta, isMaximizing)
    -- fim da busca: vitória com urgência (quanto antes melhor) ou aval. estática
    local winner = boardInstance:checkWinner()
    if winner == 2 then return 1000 + depth end
    if winner == 1 then return -1000 - depth end
    if depth == 0 then return AI.evaluate(boardInstance) end

    -- gera os movimentos legais da posição atual
    local allMoves = {}
    local mandatory = boardInstance:getAllPossibleCaptures()

    if #mandatory > 0 then
        for _, pPos in ipairs(mandatory) do
            local moves = boardInstance:getValidMoves(pPos.row, pPos.col, true)
            for _, m in ipairs(moves) do
                table.insert(allMoves, { startRow = pPos.row, startCol = pPos.col, endRow = m.row, endCol = m.col })
            end
        end
    else
        for r = 1, 8 do
            for c = 1, 8 do
                local p = boardInstance:getPiece(r, c)
                if p ~= 0 and p.player == boardInstance.currentPlayer then
                    local moves = boardInstance:getValidMoves(r, c, false)
                    for _, m in ipairs(moves) do
                        table.insert(allMoves, { startRow = r, startCol = c, endRow = m.row, endCol = m.col })
                    end
                end
            end
        end
    end

    if isMaximizing then
        -- nó de maximização: escolhe a melhor resposta para a IA
        local maxEval = -math.huge
        for _, move in ipairs(allMoves) do
            local tempBoard = boardInstance:copy()
            tempBoard:movePiece(move.startRow, move.startCol, move.endRow, move.endCol)
            tempBoard:changeTurn()
            local eval = AI.minimax(tempBoard, depth - 1, alpha, beta, false)
            maxEval = math.max(maxEval, eval)
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end -- poda alfa
        end
        return maxEval
    else
        -- nó de minimização: adversário fará a pior jogada para a IA
        local minEval = math.huge
        for _, move in ipairs(allMoves) do
            local tempBoard = boardInstance:copy()
            tempBoard:movePiece(move.startRow, move.startCol, move.endRow, move.endCol)
            tempBoard:changeTurn()
            local eval = AI.minimax(tempBoard, depth - 1, alpha, beta, true)
            minEval = math.min(minEval, eval)
            beta = math.min(beta, eval)
            if beta <= alpha then break end -- poda beta
        end
        return minEval
    end
end

return AI
