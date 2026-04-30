local AI = {}

-- Valores das peças
local PIECE_VALUE = 10
local KING_VALUE = 30

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

function AI.getBestMove(boardInstance, depth)
    local bestScore = -math.huge
    local bestMove = nil

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

function AI.minimax(boardInstance, depth, alpha, beta, isMaximizing)
    local winner = boardInstance:checkWinner()
    if winner == 2 then return 1000 + depth end
    if winner == 1 then return -1000 - depth end
    if depth == 0 then return AI.evaluate(boardInstance) end

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
        local maxEval = -math.huge
        for _, move in ipairs(allMoves) do
            local tempBoard = boardInstance:copy()
            tempBoard:movePiece(move.startRow, move.startCol, move.endRow, move.endCol)
            tempBoard:changeTurn()
            local eval = AI.minimax(tempBoard, depth - 1, alpha, beta, false)
            maxEval = math.max(maxEval, eval)
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end
        end
        return maxEval
    else
        local minEval = math.huge
        for _, move in ipairs(allMoves) do
            local tempBoard = boardInstance:copy()
            tempBoard:movePiece(move.startRow, move.startCol, move.endRow, move.endCol)
            tempBoard:changeTurn()
            local eval = AI.minimax(tempBoard, depth - 1, alpha, beta, true)
            minEval = math.min(minEval, eval)
            beta = math.min(beta, eval)
            if beta <= alpha then break end
        end
        return minEval
    end
end

return AI
