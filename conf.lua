-- Configuração do LÖVE: executada antes de love.load().
function love.conf(t)
    t.window.title     = "CheckersLua" -- título da janela
    t.window.width     = 650           -- largura inicial da janela
    t.window.height    = 560           -- altura inicial da janela
    t.window.resizable = true          -- permite redimensionar a janela
    t.window.minwidth  = 400           -- largura mínima
    t.window.minheight = 360           -- altura mínima
    t.window.vsync     = 1             -- sincroniza com o monitor (evita flicker)
    t.window.highdpi   = true          -- usa resolução nativa em telas HiDPI
    t.version          = "11.4"        -- versão do LÖVE alvo
    t.identity         = "checkerslua" -- pasta dos saves (love.filesystem)
end
