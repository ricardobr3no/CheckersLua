Config = require("config")
Piece = require("piece")

ROWS, COLS = 8, 8
SQUARE_SIZE = Config.BOARD_SIZE / 8

local OX = Config.BOARD_OFFSET_X
local OY = Config.BOARD_OFFSET_Y
local FRAME = Config.BOARD_FRAME

local function createBoard()
	local board = {}
	for row = 1, ROWS do
		board[row] = {}
		for col = 1, COLS do
			board[row][col] = 0
		end
	end

	for row = 1, ROWS do
		for col = 1, COLS do
			if (row + col) % 2 == 1 then
				if row <= 3 then
					board[row][col] = Piece.new(1, row, col)
				elseif row >= 6 then
					board[row][col] = Piece.new(2, row, col)
				end
			end
		end
	end
	return board
end

Board = {
	board = createBoard(),
	currentPlayer = 1,
	real = true,
	ghosts = {},
	shake = 0,
}

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

function Board:movePiece(oldRow, oldCol, newRow, newCol)
	local peca = self:getPiece(oldRow, oldCol)
	local isCapture, midRow, midCol = self:canCapture(oldRow, oldCol, newRow, newCol)

	self.board[oldRow][oldCol] = 0
	self.board[newRow][newCol] = peca
	peca.row, peca.col = newRow, newCol

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

	if (peca.player == 1 and newRow == ROWS) or (peca.player == 2 and newRow == 1) then
		peca:promote()
		if self.real and ShakeEnabled then
			self:addShake(3)
		end
	end

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

function Board:getPiece(row, col)
	if self.board[row] then
		return self.board[row][col]
	end
	return 0
end

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

function Board:getValidMoves(row, col, onlyCaptures)
	local piece = self:getPiece(row, col)
	if piece == 0 then
		return {}
	end

	local captureMoves = {}
	local normalMoves = {}

	local dirs = piece:getDirections()

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

	if countCurrentPlayerPieces == 0 or not currentPlayerHasMoves then
		return self.currentPlayer == 1 and 2 or 1
	end

	return nil
end

return Board
