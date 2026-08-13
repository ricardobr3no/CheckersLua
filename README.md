# CheckersLua 🎯

Jogo de **Damas** desenvolvido em Lua com o framework **LÖVE 2D**, com suporte a partida entre dois jogadores ou contra uma inteligência artificial.

---

## Requisitos

- [LÖVE 2D](https://love2d.org/) **11.x** ou superior

---

## Como executar

### Windows
```bat
love "C:\caminho\para\CheckersLua"
```

### macOS / Linux
```sh
love /caminho/para/CheckersLua
```

> **Dica:** Você também pode arrastar a pasta do projeto diretamente para o executável do LÖVE.

---

## Modos de jogo

| Modo | Descrição |
|---|---|
| **Humano vs Humano** | Dois jogadores se alternam no mesmo teclado/mouse |
| **Humano vs Computador** | O jogador controla as peças vermelhas; a IA controla as brancas |

---

## Controles

| Ação | Entrada |
|---|---|
| Selecionar peça | Clique esquerdo na peça |
| Mover peça | Clique esquerdo na casa de destino (destacada em verde) |
| Trocar peça selecionada | Clique esquerdo em outra peça válida |
| Voltar ao Menu | Botão **Menu** (durante a partida) |
| Reiniciar partida | Botão **Reiniciar** (durante a partida) |

### Indicadores visuais

| Cor | Significado |
|---|---|
| 🟡 Círculo amarelo | Peça atualmente selecionada |
| 🟢 Ponto verde | Destino de movimento normal |
| 🔴 Ponto vermelho | Destino de captura |
| 🔴 Círculo vermelho | Peça com captura obrigatória |

---

## Regras implementadas

- Movimentação diagonal nas casas escuras
- **Captura obrigatória** — se houver captura disponível, ela deve ser realizada
- **Multicaptura** — após capturar, a peça deve continuar capturando se possível
- **Promoção a Dama** — peça que alcança a última fileira adversária vira Dama (movimento em todas as direções diagonais)
- Vitória por eliminação de peças ou bloqueio total do adversário

---

## Inteligência Artificial

A IA utiliza o algoritmo **Minimax com profundidade 3**, avaliando o tabuleiro com base no número e tipo de peças:

| Peça | Valor |
|---|---|
| Peça normal | 10 |
| Dama | 30 |

A IA aguarda **1 segundo** antes de cada jogada para tornar a partida mais fluida.

---

## Estrutura do projeto

```
CheckersLua/
├── main.lua       # Ponto de entrada do LÖVE (load / update / draw / input)
├── conf.lua       # Configuração da janela (título, dimensões)
├── assets/
│   ├── crown.png                    # Ícone de Dama
│   ├── bg_awesomeness.wav           # Música de fundo
│   ├── sound_board_move_asset.wav   # Som de movimento
│   └── sound_board_jump_asset.wav   # Som de captura
└── src/
    ├── game.lua     # Lógica central: estados, input, IA, renderização
    ├── board.lua    # Tabuleiro: movimentos, capturas, promoção, vitória
    ├── piece.lua    # Peça individual: direções, promoção, desenho
    ├── ai.lua       # Inteligência artificial (Minimax)
    ├── ui.lua       # Sistema de botões reutilizável
    ├── history.lua  # Histórico de jogadas (notação, scroll)
    ├── settings.lua # Preferências do jogador (load/save em disco)
    ├── view.lua     # Câmera virtual (escala centralizada)
    └── config.lua   # Configurações globais (resolução, modos)
```

---

## Licença

Distribuído sob a licença **Apache 2.0**. Consulte o arquivo [`LICENSE`](LICENSE) para mais detalhes.
