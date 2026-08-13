-- Configurações centrais do jogo (resolução, tamanho do tabuleiro e modos).
-- O jogo renderiza numa resolução virtual fixa e o view.lua escala/centraliza
-- para caber na janela, então estes valores definem o "mundo" do jogo.
return {
    SCREEN_HEIGHT  = 560,          -- altura da resolução virtual
    SCREEN_WIDTH   = 680,          -- largura da resolução virtual
    BOARD_SIZE     = 500,          -- lado do tabuleiro em pixels (8x8 casas)
    BOARD_OFFSET_X = 20,           -- margem esquerda do tabuleiro
    BOARD_OFFSET_Y = 20,           -- margem superior do tabuleiro
    BOARD_FRAME    = 18,           -- espessura da moldura ao redor do tabuleiro
    MODES = { PVP = 1, PVC = 2 },  -- modos de jogo: 2 jogadores ou vs IA
}
