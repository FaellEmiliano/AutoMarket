# Contrato de resolução da UI

AutoMarket mantém o canvas lógico padrão de **1152×648** (16:9) como referência para a interface desktop. Superfícies responsivas, como a IDE, adaptam seu próprio overlay sem alterar a resolução global do jogo.

## Escala

- O modo de stretch é `canvas_items`, para que cenas 2D e `Control` sejam escalados juntas.
- O aspecto é `keep`: telas que não forem 16:9 recebem barras em vez de distorcer a interface.
- O filtro padrão de canvas permanece `nearest`, preservando a nitidez da pixel art.

## Resoluções verificadas

As verificações da fundação cobrem 1152×648, 1280×720 e 960×540. A tela inicial deve permanecer utilizável nessas resoluções; os tickets de cada superfície de UI devem adicionar a mesma validação para seus controles essenciais. Layouts menores podem reorganizar conteúdo, mas não podem cortar controles ou texto essencial.

## Como validar

Execute a cena `tests/ui_viewport_contract_test.tscn` pelo Godot. Ela garante os valores do contrato, verifica os controles essenciais da tela inicial e, em execução gráfica, grava capturas em `user://` para inspeção visual pelos tickets seguintes.
