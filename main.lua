-- Ponto de entrada do LÖVE: repassa os callbacks do framework para o Game.
-- Todo o estado e a lógica ficam em game.lua; aqui só há a ponte.
local Game = require("game")

function love.load()              -- chamado uma vez no início
    Game.load()
end

function love.update(dt)          -- dt = tempo em segundos desde o último frame
    Game.update(dt)
end

function love.draw()              -- desenha a cena atual
    Game.draw()
end

function love.mousepressed(x, y, button) -- clique do mouse
    Game.mousepressed(x, y, button)
end

function love.wheelmoved(x, y)    -- rolagem da roda do mouse
    Game.wheelmoved(x, y)
end

function love.resize(w, h)        -- janela foi redimensionada
    Game.resize(w, h)
end

function love.keypressed(key)     -- tecla pressionada
    Game.keypressed(key)
end
