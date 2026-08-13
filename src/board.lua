-- Tabuleiro de damas: regras, movimentação, captura, promoção e desenho.
-- Observação: o módulo expõe globais (Board, ROWS, COLS, SQUARE_SIZE) por
-- compatibilidade com o restante do código; todos os arquivos os usam.
Config = require("src.config")
Piece = require("src.piece")

ROWS, COLS = 8, 8                  -- tabuleiro 8x8
SQUARE_SIZE = Config.BOARD_SIZE / 8 -- tamanho da casa em pixels

local OX = Config.BOARD_OFFSET_X
local OY = Config.BOARD_OFFSET_Y
local FRAME = Config.BOARD_FRAME

-- Monta o estado inicial: peças do jogador 1 (vermelho) na base (linhas 6-8)
-- e do jogador 2 (branco) no topo (linhas 1-3), somente nas casas escuras.
local function createBoard()
	local board = {}
	for row = 1, ROWS do
		board[row] = {}
		for col = 1, COLS do
			board[row][col] = 0 -- 0 = casa vazia
		end
	end

	for row = 1, ROWS do
		for col = 1, COLS do
			-- casas escuras são onde as peças ficam (soma ímpar)
			if (row + col) % 2 == 1 then
				if row <= 3 then
					board[row][col] = Piece.new(2, row, col)
				elseif row >= 6 then
					board[row][col] = Piece.new(1, row, col)
				end
			end
		end
	end
	return board
end

Board = {
	board = createBoard(), -- matriz 8x8 de peças (0 = vazio)
	currentPlayer = 1,     -- quem joga agora (1 = vermelho, 2 = branco)
	real = true,           -- false para cópias usadas pela IA (sem som/efeitos)
	ghosts = {},           -- "fantasmas" das peças capturadas (animação de sumiço)
	shake = 0,             -- intensidade do tremor de tela restante
}

-- Cópia profunda do tabuleiro para simulação (IA). A cópia é "irreal":
-- não toca sons nem dispara efeitos visuais.
function Board:copy()
	local newBoard = {
		board = {},
		currentPlayer = self.currentPlayer,
		real = false,
		ghosts = {},
		shake = 0,
	}
	for r = 1, ROWS do
		newBoard.board[r] = {}
		for c = 1, COLS do
			local p = self.board[r][c]
			if p == 0 then
				newBoard.board[r][c] = 0
			else
				newBoard.board[r][c] = p:copy()
			end
		end
	end
	setmetatable(newBoard, { __index = Board })
	return newBoard
end

-- ─── Moldura ───────────────────────────────────────────────────────────────────
function Board:drawFrame()
	love.graphics.setColor(0.15, 0.09, 0.04)
	love.graphics.rectangle("fill", OX - FRAME, OY - FRAME, Config.BOARD_SIZE + FRAME * 2, Config.BOARD_SIZE + FRAME * 2, 6, 6)

	love.graphics.setColor(0.30, 0.19, 0.10)
	love.graphics.rectangle("fill", OX - FRAME + 3, OY - FRAME + 3, Config.BOARD_SIZE + (FRAME - 3) * 2, Config.BOARD_SIZE + (FRAME - 3) * 2, 5, 5)

	-- contorno claro interno
	love.graphics.setColor(0.62, 0.47, 0.30)
	love.graphics.rectangle("line", OX - 2, OY - 2, Config.BOARD_SIZE + 4, Config.BOARD_SIZE + 4)
end

function Board:drawSquares()
	for row = 1, ROWS do
		for col = 1, COLS do
			if (row + col) % 2 == 1 then
				love.graphics.setColor(0.62, 0.45, 0.28) -- escuro
			else
				love.graphics.setColor(0.95, 0.87, 0.72) -- claro
			end

			love.graphics.rectangle("fill", OX + (col - 1) * SQUARE_SIZE, OY + (row - 1) * SQUARE_SIZE, SQUARE_SIZE, SQUARE_SIZE)
		end
	end

	-- vinco sutil da grade
	love.graphics.setColor(0, 0, 0, 0.05)
	love.graphics.rectangle("line", OX, OY, Config.BOARD_SIZE, Config.BOARD_SIZE)
end

-- ─── Animação ──────────────────────────────────────────────────────────────────
function Board:update(dt)
	self.shake = math.max(0, self.shake - dt * 2.4)

	for r = 1, ROWS do
		for c = 1, COLS do
			local p = self:getPiece(r, c)
			if p ~= 0 then
				p:update(dt)
			end
		end
	end

	for i = #self.ghosts, 1, -1 do
		local g = self.ghosts[i]
		g.alpha = g.alpha - dt * 2.5
		if g.alpha <= 0 then
			table.remove(self.ghosts, i)
		end
	end
end

function Board:addShake(amount)
	self.shake = math.min(8, self.shake + amount)
end

-- ─── Regras ────────────────────────────────────────────────────────────────────
-- Verifica se mover de (oldRow,oldCol) para (newRow,newCol) é uma captura:
-- deve pular 2 casas na diagonal sobre uma peça inimiga com destino vazio.
-- Retorna true + a posição da peça capturada (casa do meio).
function Board:canCapture(oldRow, oldCol, newRow, newCol)
	if math.abs(newRow - oldRow) == 2 and math.abs(newCol - oldCol) == 2 then
		local midRow = (newRow + oldRow) / 2
		local midCol = (newCol + oldCol) / 2
		local pecaMid = self:getPiece(midRow, midCol)
		local pecaDest = self:getPiece(newRow, newCol)

		if pecaMid ~= 0 and pecaMid.player ~= self.currentPlayer and pecaDest == 0 then
			return true, midRow, midCol
		end
	end
	return false
end

-- Executa o movimento. Se for captura, remove a peça do meio (gerando um
-- "ghost" animado) e retorna true. Também promove a peça quando chega à
-- última fileira e toca o som apropriado (só se for o tabuleiro real).
function Board:movePiece(oldRow, oldCol, newRow, newCol)
	local peca = self:getPiece(oldRow, oldCol)
	local isCapture, midRow, midCol = self:canCapture(oldRow, oldCol, newRow, newCol)

	-- desloca a peça para a nova casa
	self.board[oldRow][oldCol] = 0
	self.board[newRow][newCol] = peca
	peca.row, peca.col = newRow, newCol

	-- captura: remove a peça pulada e deixa um "ghost" que some aos poucos
	if isCapture and midRow and midCol then
		local captured = self:getPiece(midRow, midCol)
		if self.real then
			table.insert(self.ghosts, {
				x = (midCol - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
				y = (midRow - 1) * SQUARE_SIZE + SQUARE_SIZE / 2,
				r = SQUARE_SIZE * 0.42,
				player = captured.player,
				isKing = captured.isKing,
				alpha = 1,
			})
			if ShakeEnabled then
				self:addShake(6)
			end
		end
		self.board[midRow][midCol] = 0
	end

	-- promoção: jogador 1 vira dama na linha 1; jogador 2 na linha 8
	if (peca.player == 1 and newRow == 1) or (peca.player == 2 and newRow == ROWS) then
		peca:promote()
		if self.real and ShakeEnabled then
			self:addShake(3)
		end
	end

	-- som (somente no tabuleiro real)
	if self.real then
		if isCapture then
			if CaptureSound then
				MoveSound:stop()
				CaptureSound:stop()
				CaptureSound:play()
			end
		else
			if MoveSound then
				CaptureSound:stop()
				MoveSound:stop()
				MoveSound:play()
			end
		end
	end

	return isCapture
end

-- Retorna a peça em (row,col) ou 0 se a casa estiver vazia.
function Board:getPiece(row, col)
	if self.board[row] then
		return self.board[row][col]
	end
	return 0
end

-- Reinicia o tabuleiro para a posição inicial.
function Board:restart()
	self.board = createBoard()
	self.currentPlayer = 1
	self.ghosts = {}
	self.shake = 0
end

Board.showBoard = function()
	for row = 1, ROWS do
		for col = 1, COLS do
			local p = Board.board[row][col]
			io.write((type(p) == "table" and p.player or p) .. ", ")
		end
		print()
	end
end

-- ─── Desenho do tabuleiro completo (com shake) ─────────────────────────────────
function Board:drawBoard(opts)
	love.graphics.push()
	if self.shake > 0 then
		local mag = self.shake
		love.graphics.translate((love.math.random() * 2 - 1) * mag, (love.math.random() * 2 - 1) * mag)
	end
	self:drawFrame()
	self:drawSquares()
	self:drawPieces(opts)
	love.graphics.pop()
end

function Board:drawPieces(opts)
	opts = opts or {}

	for _, g in ipairs(self.ghosts) do
		Piece.drawGhost(OX + g.x, OY + g.y, g.r * (1.2 - g.alpha * 0.2), g.player, g.isKing, g.alpha)
	end

	for row = 1, ROWS do
		for col = 1, COLS do
			local piece = self:getPiece(row, col)
			if piece ~= 0 then
				piece:draw(
					OX + piece.displayX,
					OY + piece.displayY,
					SQUARE_SIZE,
					{
						hovered = opts.hoverRow == row and opts.hoverCol == col,
						glow = opts.selectedRow == row and opts.selectedCol == col,
					}
				)
			end
		end
	end
end

-- Passa a vez ao outro jogador.
function Board:changeTurn()
	if self.currentPlayer == 1 then
		self.currentPlayer = 2
	else
		self.currentPlayer = 1
	end
	if self.real then
		print("Vez do jogador " .. self.currentPlayer)
	end
end

-- Lista todas as peças do jogador atual que têm captura disponível.
-- Como a captura é obrigatória nas damas, a IA e a seleção usam isto.
function Board:getAllPossibleCaptures()
	local mandatoryPieces = {}

	for r = 1, ROWS do
		for c = 1, COLS do
			local piece = self:getPiece(r, c)
			if piece ~= 0 and piece.player == self.currentPlayer then
				local moves = self:getValidMoves(r, c, true)
				local hasCapture = false
				for _, m in ipairs(moves) do
					if m.isCapture then
						hasCapture = true
						break
					end
				end

				if hasCapture then
					table.insert(mandatoryPieces, { row = r, col = c })
				end
			end
		end
	end
	return mandatoryPieces
end

-- Movimentos válidos da peça em (row,col).
-- Capturas têm prioridade: se houver alguma, são as únicas retornadas
-- (captura obrigatória). Se onlyCaptures for true, ignora movimentos simples.
function Board:getValidMoves(row, col, onlyCaptures)
	local piece = self:getPiece(row, col)
	if piece == 0 then
		return {}
	end

	local captureMoves = {}
	local normalMoves = {}

	local dirs = piece:getDirections()

	-- salto de 2 casas = captura (se houver inimigo no meio e destino vazio)
	for _, dir in ipairs(dirs) do
		local r2, c2 = row + (dir[1] * 2), col + (dir[2] * 2)
		if r2 >= 1 and r2 <= ROWS and c2 >= 1 and c2 <= COLS then
			local isCap, _, _ = self:canCapture(row, col, r2, c2)
			if isCap then
				table.insert(captureMoves, { row = r2, col = c2, isCapture = true })
			end
		end
	end

	if #captureMoves > 0 then
		return captureMoves
	end
	if onlyCaptures then
		return {}
	end

	-- movimento simples de 1 casa na diagonal, para casa vazia
	for _, dir in ipairs(dirs) do
		local r1, c1 = row + dir[1], col + dir[2]
		if r1 >= 1 and r1 <= ROWS and c1 >= 1 and c1 <= COLS then
			if self:getPiece(r1, c1) == 0 then
				table.insert(normalMoves, { row = r1, col = c1, isCapture = false })
			end
		end
	end

	return normalMoves
end

-- Verifica se o jogo terminou: o jogador atual perdeu todas as peças ou não
-- tem mais nenhum movimento possível. Retorna o vencedor ou nil (continua).
function Board:checkWinner()
	local countCurrentPlayerPieces = 0
	local currentPlayerHasMoves = false

	for row = 1, ROWS do
		for col = 1, COLS do
			local piece = self:getPiece(row, col)
			if piece ~= 0 and piece.player == self.currentPlayer then
				countCurrentPlayerPieces = countCurrentPlayerPieces + 1
				local validMoves = self:getValidMoves(row, col, false)
				if #validMoves > 0 then
					currentPlayerHasMoves = true
				end
			end
		end
	end

	-- quem perdeu é o jogador da vez: então o outro vence
	if countCurrentPlayerPieces == 0 or not currentPlayerHasMoves then
		return self.currentPlayer == 1 and 2 or 1
	end

	return nil
end

return Board
